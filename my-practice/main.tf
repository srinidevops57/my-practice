provider "aws" {
  region = "us-east-1" # specify your desired AWS region
}

resource "aws_instance" "example" {
  ami           = "ami-03265a0778a880afb" # specify the AMI ID
  instance_type = "t2.micro"               # specify the instance type

  tags = {
    Name = "ExampleInstance"
  }
}