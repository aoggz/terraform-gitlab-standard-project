
terraform {
  required_version = ">= 0.12.0"
}

variable "name" {
  type        = string
  description = "Name of project to create"
}

variable "description" {
  type        = string
  description = "Description of project"
}

variable "parent_id" {
  type        = string
  description = "Id of parent group"
}

variable "slack_webhook_url" {
  type        = string
  description = "Webhook URL to use for Slack service integration"
}

variable "visibility" {
  type        = string
  description = "Visibility setting of GitLab project"
  default     = "internal"
}

resource "gitlab_project" "main" {
  name        = "${var.name}"
  description = "${var.description}"

  visibility_level                                 = "internal"
  namespace_id                                     = "${var.parent_id}"
  default_branch                                   = "master"
  issues_enabled                                   = false
  merge_requests_enabled                           = true
  approvals_before_merge                           = 1
  only_allow_merge_if_pipeline_succeeds            = true
  only_allow_merge_if_all_discussions_are_resolved = true
  merge_method                                     = "merge"
}

# resource "gitlab_branch_protection" "master" {
#   project            = "${gitlab_project.main.id}"
#   branch             = "master"
#   push_access_level  = "no one"
#   merge_access_level = "maintainer"
# }

# resource "gitlab_branch_protection" "release" {
#   project            = "${gitlab_project.main.id}"
#   branch             = "release/*"
#   push_access_level  = "no one"
#   merge_access_level = "maintainer"
# }

# resource "gitlab_tag_protection" "all" {
#   project             = "${gitlab_project.main.id}"
#   tag                 = "*"
#   create_access_level = "no one"
# }


resource "gitlab_service_slack" "slack" {
  project  = "${gitlab_project.main.id}"
  webhook  = "${var.slack_webhook_url}"
  username = "GitLab"

  notify_only_default_branch = true

  merge_requests_events = true
  pipeline_events       = true
  tag_push_events       = true
}
