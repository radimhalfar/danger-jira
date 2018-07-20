require 'set'

module Danger
  # Links JIRA issues to a pull request.
  #
  # @example Check PR for the following JIRA project keys and links them
  #
  #          jira.check(key: "KEY", url: "https://myjira.atlassian.net/browse")
  #
  # @see  RestlessThinker/danger-jira
  # @tags jira
  #
  class DangerJira < Plugin
    # Checks PR for JIRA keys and links them
    #
    # @param [Array] key
    #         An array of JIRA project keys KEY-123, JIRA-125 etc.
    #
    # @param [String] url
    #         The JIRA url hosted instance.
    #
    # @param [String] emoji
    #         The emoji you want to display in the message.
    #
    # @param [Boolean] search_title
    #         Option to search JIRA issues from PR title
    #
    # @param [Boolean] search_commits
    #         Option to search JIRA issues from commit messages
    #
    # @param [Boolean] fail_on_warning
    #         Option to fail danger if no JIRA issue found
    #
    # @param [Boolean] report_missing
    #         Option to report if no JIRA issue was found
    #
    # @return [void]
    #
    def check(key: nil, url: nil, emoji: ":link:", search_title: true, search_commits: false, fail_on_warning: false, report_missing: true)
      throw Error("'key' missing - must supply JIRA issue key") if key.nil?
      throw Error("'url' missing - must supply JIRA installation URL") if url.nil?

      # Support multiple JIRA projects
      keys = nil
      if key.kind_of?(Array)
          keys = key.map { |key| "(?:"+ key + ")" }.join("|")
      else
          keys = "(#{key})"
      end

      jira_key_regex_string = /(?:\[((?:#{keys})-[0-9]+)\])/
      regexp = Regexp.new("#{jira_key_regex_string}")

      jira_issues = []

      if search_title
        jira_issues << gitlab.mr_title.scan(regexp)
      end
      if search_commits
        jira_issues << git.commits.map { |commit| commit.message.scan(regexp) }.flatten.compact
      end
      
      has_issues = !jira_issues[0].empty? || !jira_issues[1].empty?
      jira_mr_issues = jira_issues[0].map {|item| item[0]}.to_set.to_a
      jira_commit_issues = jira_issues[1].map {|item| item[0]}.to_set.to_a

      jira_issues = jira_mr_issues + jira_commit_issues

      if !jira_issues.empty? && has_issues
        jira_urls = jira_issues.map { |issue| link(href: ensure_url_ends_with_slash(url), issue: issue) }.join(", ")
        message("#{emoji} #{jira_urls}")
      elsif report_missing
        msg = "This PR does not contain any JIRA issue keys in the PR title or commit messages (e.g. KEY-123)"
        if fail_on_warning
          fail(msg)
        else
          warn(msg)
        end
      end
    end

    private

    def ensure_url_ends_with_slash(url)
      return "#{url}/" unless url.end_with?("/")
      return url
    end

    def link(href: nil, issue: nil)
      return "<a href='#{href}#{issue}'>#{issue}</a>"
    end
  end
end
