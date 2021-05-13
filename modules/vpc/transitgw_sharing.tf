###
# Do resource lookups we'll need
# ------------------------------
# 
data "aws_caller_identity" "second" {
  count    = var.use_transit_gw && var.remote_transit_gw ? 1 : 0
  provider = aws
}

###
# Lookup AWS Orgs ID
# ------------------
# This is temporarily disabled, since Org ID RAM sharing is broken
#data "aws_organizations_organization" "this" {
#  count    = "${var.create_transit_gw && var.share_transit_gw ? 1 : 0}"
#  provider = "aws.orgs"
#}

###
# Transit Gateway Sharing
# -----------------------
# Transit Gateway Sharing requires 5 steps, we'll cover individually:
# 1) Make a resource share in AWS Resource Access Manager
resource "aws_ram_resource_share" "transitgw" {
  count = var.create_transit_gw && var.share_transit_gw && false == var.remote_transit_gw ? 1 : 0

  #provider                  = "aws.transitgw"
  provider = aws

  name                      = "${var.environment}-transitgw"
  allow_external_principals = var.allow_external_principals

  tags = {
    Name = "${var.environment}-transitgw"
  }
}

# 2) Make a resource association between the RAM share and the transitgw we created
resource "aws_ram_resource_association" "transitgw" {
  count = var.create_transit_gw && var.share_transit_gw && false == var.remote_transit_gw ? 1 : 0

  #provider           = "aws.transitgw"
  provider = aws

  resource_arn       = aws_ec2_transit_gateway.this[0].arn
  resource_share_arn = aws_ram_resource_share.transitgw[0].id
  depends_on = [
    aws_ram_resource_share.transitgw,
    aws_ec2_transit_gateway.this,
  ]
}

# 3) Share the AWS RAM Resource share we associated with transitgw with the account
# we want to add into the transitgw
resource "aws_ram_principal_association" "transitgw" {
  count    = var.use_transit_gw && var.remote_transit_gw ? 1 : 0
  provider = aws.transitgw

  #  principal          = "${data.aws_organizations_organization.this.arn}" 
  principal          = data.aws_caller_identity.second[0].account_id
  resource_share_arn = var.transit_gw_share_arn
}

# 4) Accept the AWS RAM Principal Association in the second account.
# Unfortunately, this isn't in Terraform yet!  You have to do this in the
# RAM console of the destination account or using the aws cli.  Look under
# the Resource Access Manager of the second AWS account, look under "Shared 
# with me" and select the "shared-transitgw" invitiation and then click 
# "Accept resource share".  This will not be required when the following
# features are completed in Terraform:
# - Expose share invitation ARN via aws_ram_principal_association output:
#     https://github.com/terraform-providers/terraform-provider-aws/issues/9432
# - Implement new resource to accept the share RAM share invitation:
#     https://github.com/terraform-providers/terraform-provider-aws/issues/7601
#
# Here is a mockup of this resource implemented in this module:
#
#resource "aws_ram_principal_accepter" "second" {
#  count                         = "${var.use_transit_gw && var.remote_transit_gw ? 1 : 0}"
#  provider                      = "aws"
#  resource_share_invitation_arn = "${var.transit_gw_invite_arn}"
#}
