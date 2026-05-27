

resource "aws_efs_file_system" "apps" {
  creation_token   = "apps-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "apps-efs"
  }
}

resource "aws_efs_file_system" "scratch" {
  creation_token   = "scratch-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "scratch-efs"
  }
}

resource "aws_efs_file_system" "home" {
  creation_token   = "home-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "home-efs"
  }
}


resource "aws_efs_mount_target" "apps_mount" {
  file_system_id  = aws_efs_file_system.apps.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "home_mount" {
  file_system_id  = aws_efs_file_system.home.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "scratch_mount" {
  file_system_id  = aws_efs_file_system.scratch.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Local variable mapping efs names to IDs
locals {

  subnet_ids = [aws_subnet.public.id]

  efs_filesystems = {
    apps    = aws_efs_file_system.apps.id
    scratch = aws_efs_file_system.scratch.id
    home    = aws_efs_file_system.home.id
  }
}
