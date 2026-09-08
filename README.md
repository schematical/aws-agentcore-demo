# Schematical AWS AgentCore Demo

## Requirements:
1) You will need an [AWS Account](https://signin.aws.amazon.com/signup?request_type=register)
2) You will need the latest AWS cli tool installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3) You will need [the Terraform CLI installed](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
4) You will want to clone down this repo.


### A note on costs:
Building this, the main thing I got charged for was Bedrock Invocations. 
This only ran me under $1 but if you got chatty with it or gave it a complicated workload, this will go up.

## Stage 0 - Shared Assets:
Directory: [./0-util](./0-util)
This sets up shared assets that will be used by several of our configurations. Its main purpose it to speed up the demo so we only have to spin it up once.


Included in it is a Vector Index and DynamoDB cluster.

```
cd ./0-util/terraform
terraform plan
#terraform apply

```

### Dynamo Knowledge Base:
./0-util/terraform/dynamodb_knowledge_base.tf](./0-util/terraform/dynamodb_knowledge_base.tf)

NOTE: At the time I am writing this there is NOT yet a Terraform resource for the vector index so that is added via a script that runs on build. As soon as TF catches up with AWS I suggest rewriting that.

### Embedding Lambda Triggerd By DynamoDB On Create/Update:
[./0-util/build/dynamo-lambda/handler.js](./0-util/build/dynamo-lambda/handler.js)


### Search Lambda:
[./0-util/build/dynamo-lambda-search/handler.js](./0-util/build/dynamo-lambda-search/handler.js)
This lambda converts a text search into and embedding which can be used to perform a vector search against DynamoDB.

### Seed Script:
[./0-util/scripts/seed_knowledge_base_from_rss.js](./0-util/scripts/seed_knowledge_base_from_rss.js)


## Stage 1 - Bare Harness:
Directory: [./1-bare-harness](./1-bare-harness)

### Main Harness:
[./1-bare-harness/terraform/main.tf](./1-bare-harness/terraform/main.tf)
This sets up a bare-bones agent harness.

### IAM Role:
[./2-memory/terraform/iam.tf](./2-memory/terraform/iam.tf)



### Talking Points:
- [ ] The Agent should have no memory based on session or otherwise.
- [ ] Show logging
- [ ] O'Reilly's Course - [Zero to Hero on AWS Security: An Animated Guide to Security in the Cloud](https://learning.oreilly.com/course/zero-to-hero/0642572107789/)


## Stage 2 - Memory:
Directory: [./2-memory/](./2-memory/)
This gives your agent basic memory.

### Main Harness:
[./2-memory/terraform/main.tf](./2-memory/terraform/main.tf)
This now should have the addition of the following block which gives it some basic memory based on sessions.
```
  memory {
    managed_memory_configuration {
      event_expiry_duration = 14
      strategies             = ["SEMANTIC", "SUMMARIZATION"]
    }
  }
```
### Talking Points:
- [ ] Demonstrate memory by `actorId`
- [ ] "Can you remember my name?"
- [ ] "My name is XZY remember it."

## Stage 3 - Browser Tool:
Directory: [./3-browser-tool](./3-browser-tool)

In this one we give the agent access to open a browser and browse the web.

The main codeblock to add access to the browser is as follows:
```
tool {
    type = "agentcore_browser"
    name = "browser"
}
```
- [ ] Show AgentCore browser in action: https://us-east-1.console.aws.amazon.com/bedrock-agentcore/browser
- [ ] Run prompt: "Can you browse to http://datacamp.com/blog and get the latest post?"

## Stage 4 - MCP Gateway:
In this stage we give access to the DynamoDB knowledgeable via a MCP with AgentCoreGateway and a Lambda

### AgentCore Gateway:
[./4-mcp-gateway/terraform/gateway.tf](./4-mcp-gateway/terraform/gateway.tf)

This takes incoming requests using MCP and then invokes the Lambda with the incoming request as Lambda context.
Then it returns the response to the party making the MCP request.

### SSM:
[./4-mcp-gateway/terraform/ssm.tf](./4-mcp-gateway/terraform/ssm.tf)

This stores the MCP Gateway's URL so the agent(or other agents) knows where to point the MCP requests at.



## Extra:

### AgentCore Runtime vs Harness:
Runtime lets you bring your own code to the inner workings of an agent harness.

For most beginners if you want to use AgentCore I suggest sticking with harness unless you want to really be platform-agnostic, in which case probably don't use AgentCore.


### Extra Cost Management:
- [ ] https://us-east-1.console.aws.amazon.com/costmanagement/home?region=us-east-1#/cost-explorer?chartStyle=STACK&costAggregate=netUnblendedCost&endDate=2026-08-31&excludeForecasting=true&filter=%5B%7B%22dimension%22:%7B%22id%22:%22Service%22,%22displayValue%22:%22Service%22%7D,%22operator%22:%22INCLUDES%22,%22values%22:%5B%7B%22value%22:%22Amazon%20Bedrock%22,%22displayValue%22:%22Bedrock%22%7D%5D%7D%5D&futureRelativeRange=CUSTOM&granularity=Daily&groupBy=%5B%22Service%22%5D&historicalRelativeRange=CUSTOM&isDefault=true&reportMode=STANDARD&reportName=New%20cost%20and%20usage%20report&showOnlyUncategorized=false&showOnlyUntagged=false&startDate=2026-08-01&usageAggregate=undefined&useNormalizedUnits=false
- [ ] https://schematical.com/book









------
## Matt's Notes:



```
terraform apply -var="project_name=my-web-app"
```


```bash
cd 0-util/terraform && terraform init && terraform apply   # once, if not already applied

cd ../../final/terraform
terraform init
terraform apply
```
- [ ] Add slides + Explanations