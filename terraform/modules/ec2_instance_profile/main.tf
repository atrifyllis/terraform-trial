resource "aws_iam_instance_profile" "asg-iam-ip" {
  name = "asg-iam-instance-profile"
  role = aws_iam_role.asg-iam-role.name
}

resource "aws_iam_role" "asg-iam-role" {
  name               = "asg-iam-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "instance_profile_policy" {
  name   = "ecs_instance_profile_role_policy"
  role   = aws_iam_role.asg-iam-role.name
  policy = data.template_file.instance_profile_file.rendered
}


data "template_file" "instance_profile_file" {
  template = file("${path.module}/instance-profile-policy.json")

  vars = {
    app_log_group_arn = aws_cloudwatch_log_group.ec2_log_group.arn
  }
}

resource "aws_cloudwatch_log_group" "ec2_log_group" {
  name = "ec2_log_group/app"
}
