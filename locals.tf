locals{
  env="${terraform.workspace}"

  region = {
    prod = "us-east-2"
    dev = "us-east-1"
  }
  blocks = {
    prod = "10.0.0.0/16"
    dev = "10.10.0.0/16"
  }
  public_subnets = {
    prod = ["10.0.0.0/23"]
    dev = ["10.10.0.0/23"]
  }
  private_subnets = {
    prod = ["10.0.10.0/23"]
    dev = ["10.10.10.0/23"]
  }
}