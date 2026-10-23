data "aws_iam_policy_document" "deploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "witnessed-examples-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume.json
}
