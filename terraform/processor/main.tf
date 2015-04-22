provider "aws" {
    region = "${var.region}"
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
}

resource "aws_security_group" "ec2-processor-sg" {
    name = "ec2-processor-sg"
    description = "Socorro processor security group."
    ingress {
        from_port = "${var.alt_ssh_port}"
        to_port = "${var.alt_ssh_port}"
        protocol = "tcp"
        cidr_blocks = [
            "0.0.0.0/0"
        ]
    }
    tags {
        Environment = "${var.environment}"
        role = "processor"
        project = "socorro"
    }
}

resource "aws_launch_configuration" "lc-processor" {
    name = "lc-${var.environment}-processor"
    user_data = "${file(\"socorro_role.sh\")} ${var.puppet_archive} processor ${var.secret_bucket} ${var.environment}"
    image_id = "${lookup(var.base_ami, var.region)}"
    instance_type = "t2.micro"
    key_name = "${lookup(var.ssh_key_name, var.region)}"
    iam_instance_profile = "generic"
    associate_public_ip_address = true
    security_groups = [
        "${aws_security_group.ec2-processor-sg.id}"
    ]
}

resource "aws_autoscaling_group" "as-processor" {
    name = "as-${var.environment}-processor"
    vpc_zone_identifier = ["${split(",", var.subnets)}"]
    availability_zones = [
        "${var.region}a",
        "${var.region}b",
        "${var.region}c"
    ]
    depends_on = [
        "aws_launch_configuration.lc-processor"
    ]
    launch_configuration = "${aws_launch_configuration.lc-processor.id}"
    max_size = 1
    min_size = 1
    desired_capacity = 1
    tag {
      key = "Environment"
      value = "${var.environment}"
      propagate_at_launch = true
    }
    tag {
      key = "role"
      value = "processor"
      propagate_at_launch = true
    }
    tag {
      key = "project"
      value = "socorro"
      propagate_at_launch = true
    }
}
