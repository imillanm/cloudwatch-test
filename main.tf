//Define el privder de AWS
provider "aws" {
  region = local.region
}

//DS:bloque de código que permite hacer querys de datos sobre recuros que no estamos manejando dese TF
//Data Source para obtener el ID de la VPC por defecto que se asigna ( la ocupo en aws-alb-target-group)
data "aws_vpc" "default" {
  default = true // si esta en true devuelve la vpc por defecto que hay en aws
}

// Variables locals, si tenemos valores repetidos agruparlos en bloques llamados locals y referenciarlos
locals {
  region = "us-west-2"
  ami    = var.ubuntu_ami[local.region]
}

// data source SUBNET con for_each para no tener que copiar y pegar uno y otro.
data "aws_subnet" "public_subnet" {
  for_each          = var.servidores // recordar que se ejecuta sobre un map
  availability_zone = "${local.region}${each.value.az}"
}

// Define una instancia EC2 con AMI ubuntu
resource "aws_instance" "servidor" {
  for_each      = var.servidores
  ami           = local.ami
  instance_type = var.tipo_instancia
  subnet_id     = data.aws_subnet.public_subnet[each.key].id // Capturamos la key que seria ser-1 o ser-2 dentro de las variables

  //Asociar instancia con Security groups y colocamos una referencia al SG
  vpc_security_group_ids = [aws_security_group.grupo_de_seguridad.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  //Coneccion SSH keyname con Keypair en AWS
  //key_name = "aws_keypair"

  //Comandos para que ejecute un servidor en puerto 8080 y muestre fichero ondex.html con un mensaje
  user_data = <<-EOF
              #!/bin/bash
              sudo su -
              yum update -y
              yum install -y awslogs
              cd /var/log
              echo "primer log de la app" > apptest.log
              sed -i 's%file = /var/log/messages%file = /var/log/apptest.log%g' /etc/awslogs/awslogs.conf
              sed -i 's%log_group_name = /var/log/messages%log_group_name = /var/log/mensages%g' /etc/awslogs/awslogs.conf
              sed -i 's%region = us-east-1%region = us-west-2%g' /etc/awslogs/awscli.conf
              sudo service awslogsd start
              EOF         
  tags = {
    Name = each.value.nombre
  }
}

//roles politica con tf y congfiruacion de la maquina con ANSIBLE
// ansble template crear lña carpeta dentro del repo -- j2 es la extension

//Grupo de seguridad con acceso al puerto 8080
resource "aws_security_group" "grupo_de_seguridad" {
  name   = "servidor-sg"
  vpc_id = data.aws_vpc.default.id
  //Definimos los ingress que tendria el bloque CIDR todas las IP
  ingress {
    cidr_blocks = ["0.0.0.0/0"] // todas las ip
    description = "Acceso al puerto 8080 desde el exterior"
    from_port   = var.puerto_servidor // puerto que vamos a abrir con la to_port
    to_port     = var.puerto_servidor
    protocol    = "TCP" // protocolo que utilizaremos
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"] // todas las ip
    description = "Acceso al puerto 80 desde el exterior"
    from_port   = var.puerto_lb // puerto que vamos a abrir con la to_port
    to_port     = var.puerto_lb
    protocol    = "TCP"
  }

  //Regla de entrada para SSH
  ingress {
    cidr_blocks = ["0.0.0.0/0"] // todas las ip
    description = "SSH"
    from_port   = 22 // puerto que vamos a abrir con la to_port
    to_port     = 22
    protocol    = "TCP"
  }

  //Regla salida (Con esta permitimos instalar cosas para ansible con playbook)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "cw_logs_ec2_policy" {
  name        = "cw_logs_ec1"
  description = "politica de cloudwatch agent"
  path        = "/"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ],
          "Resource" : [
            "*"
          ]
        }
      ]
  })
}

resource "aws_iam_role" "cw_ec2_role" {
  name        = "cw_ec2_role"
  description = "rol cw ec2"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Effect" : "Allow",
          "Sid" : "",
          "Principal" : {
            "Service": "ec2.amazonaws.com"
        }
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_attachment" {
  role       = aws_iam_role.cw_ec2_role.name
  policy_arn = aws_iam_policy.cw_logs_ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.cw_ec2_role.name
}


