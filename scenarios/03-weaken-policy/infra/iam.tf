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

data "aws_iam_policy_document" "deploy_publish" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.deploys.arn]
  }
}

resource "aws_iam_role_policy" "deploy_publish" {
  name   = "publish-deploy-notifications"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_publish.json
}
