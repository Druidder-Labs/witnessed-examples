resource "aws_sns_topic" "deploys" {
  name              = "witnessed-examples-deploys"
  display_name      = "Deployment notifications"
  kms_master_key_id = "alias/aws/sns"
}
