resource "aws_iam_role" "ecs-host-role" {
  name               = "ecs_host_role_stage"
  assume_role_policy = file("policies/ecs-role.json")
}

resource "aws_iam_role_policy" "ecs-instance-role-policy" {
  name   = "ecs_instance_role_policy"
  policy = file("policies/ecs-instance-role-policy.json")
  role   = aws_iam_role.ecs-host-role.id
}

resource "aws_iam_role" "ecs-service-role" {
  name               = "ecs_service_role_stage"
  assume_role_policy = file("policies/ecs-role.json")
}

resource "aws_iam_role_policy" "ecs-service-role-policy" {
  name   = "ecs_service_role_policy"
  policy = file("policies/ecs-service-role-policy.json")
  role   = aws_iam_role.ecs-service-role.id
}

resource "aws_iam_instance_profile" "ecs" {
  name = "ecs_instance_profile_stage"
  path = "/"
  role = aws_iam_role.ecs-host-role.name
}

resource "aws_iam_role" "ecs-execution-role" {
  name               = "ecs_execution_role"

  inline_policy {
    name = "ecr_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action  = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetRepositoryPolicy",
            "ecr:DescribeRepositories",
            "ecr:ListImages",
            "ecr:DescribeImages",
            "ecr:BatchGetImage",
            "ecr:GetLifecyclePolicy",
            "ecr:GetLifecyclePolicyPreview",
            "ecr:ListTagsForResource",
            "ecr:DescribeImageScanFindings",
            "logs:CreateLogStream"
          ],
          Effect  = "Allow"
          Resource = "*"
        }
      ]
    })
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
