
terraform {
  required_version = ">= 0.12.0"
}

variable "name" {
  type        = string
  description = "Name of project"
}

variable "description" {
  type        = string
  description = "Description of project"
}

variable "path" {
  type        = string
  description = "Path of project"
  default     = null
}

variable "parent_id" {
  type        = string
  description = "Id of parent group"
}

variable "only_allow_merge_if_pipeline_succeeds" {
  type        = bool
  description = "Merges can only succeed if a pipeline exists and succeeds"
  default     = true
}

variable "project_push_rules_enabled" {
  type        = bool
  description = "Whether push rules will be created"
  default     = true
}

variable "project_push_rules_branch_name_regex" {
  type        = string
  default     = "^(release\\/\\d+\\.\\d+)|((feature|hotfix|bugfix|renovate)\\/.+)|((cherry-pick|revert)-.+)$"
  description = "Required branch name. Only used if project_push_rules_enabled = true"
}

variable "project_push_rules_commit_message_regex" {
  type        = string
  default     = "^(Merge)|((ci|chore|docs|feat|feature|fix|refactor|test|BREAKING_CHANGE):).*"
  description = "Required commit message syntax. Only used if project_push_rules_enabled = true"
}

variable "slack_webhook_url" {
  type        = string
  description = "Webhook URL to use for Slack service integration"
}

variable "master_branch_protection_enabled" {
  type        = bool
  description = "Whether master branch protection is enabled"
  default     = true
}

variable "repo_destruction_protection_disabled" {
  type        = bool
  description = "Whether gitlab_project resource is protected from distruction"
  default     = false
}

variable "repo_shared_runners_enabled" {
  type        = bool
  description = "Whether shared runners are enabled for the gitlab_project"
  default     = true
}

variable "merge_method" {
  type        = string
  description = "Merge method to use on merge requests"
  default     = "merge"
}

resource "gitlab_project" "main" {
  name        = var.name
  path        = var.path
  description = var.description

  visibility_level                                 = "internal"
  namespace_id                                     = var.parent_id
  default_branch                                   = "master"
  issues_enabled                                   = false
  merge_requests_enabled                           = true
  approvals_before_merge                           = 1
  only_allow_merge_if_pipeline_succeeds            = var.only_allow_merge_if_pipeline_succeeds
  only_allow_merge_if_all_discussions_are_resolved = true
  merge_method                                     = var.merge_method
  shared_runners_enabled                           = var.repo_shared_runners_enabled
  # initialize_with_readme                           = true
}

resource "gitlab_project_push_rules" "main" {
  count                = var.project_push_rules_enabled ? 0 : 1
  commit_message_regex = var.project_push_rules_commit_message_regex
  project              = gitlab_project.main.id
  deny_delete_tag      = true
  prevent_secrets      = true
  branch_name_regex    = var.project_push_rules_branch_name_regex
  # commit_committer_check = true
}

# Prevents destruction of user_pool in controlled stages 
# https://github.com/hashicorp/terraform/issues/3116#issuecomment-292038781
resource "random_id" "protector" {
  count       = var.repo_destruction_protection_disabled ? 0 : 1
  byte_length = 8

  keepers = {
    cup_id = gitlab_project.main.id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "gitlab_branch_protection" "master" {
  count              = var.master_branch_protection_enabled ? 1 : 0
  project            = gitlab_project.main.id
  branch             = "master"
  push_access_level  = "no one"
  merge_access_level = "maintainer"
}

resource "gitlab_branch_protection" "release" {
  project            = gitlab_project.main.id
  branch             = "release/*"
  push_access_level  = "no one"
  merge_access_level = "maintainer"
}

resource "gitlab_tag_protection" "all" {
  project             = gitlab_project.main.id
  tag                 = "*"
  create_access_level = "maintainer"
}


resource "gitlab_service_slack" "slack" {
  project  = gitlab_project.main.id
  webhook  = var.slack_webhook_url
  username = "GitLab"

  notify_only_default_branch = true

  merge_requests_events = true
  pipeline_events       = true
  tag_push_events       = true
}

output "gitlab_project_id" {
  value       = gitlab_project.main.id
  description = "Id of created GitLab project"
}
