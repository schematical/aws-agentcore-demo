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

### Infrastructure:


```
cd ./0-util/terraform
terraform init
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

### Infrastructure:

### Main Harness:
[./1-bare-harness/terraform/main.tf](./1-bare-harness/terraform/main.tf)
This sets up a bare-bones agent harness.

### IAM Role:
[./2-memory/terraform/iam.tf](./2-memory/terraform/iam.tf)



### Talking Points:
- [ ] The Agent should have no memory based on session or otherwise.
- [ ] Show logging
- [ ] O'Reilly's Course - [Zero to Hero on AWS Security: An Animated Guide to Security in the Cloud](https://learning.oreilly.com/course/zero-to-hero/0642572107789/)

## Invoking The Harness:
We will mainly be using the test UI in the AWS console but in production you would likely [Invoke it via the API](https://docs.aws.amazon.com/bedrock-agentcore/latest/APIReference/API_InvokeHarness.html).



## Stage 2 - Memory:
Directory: [./2-memory/](./2-memory/)
This gives your agent basic memory.

### Infrastructure:


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

### Infrastructure:

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

### Infrastructure:


### AgentCore Gateway:
[./4-mcp-gateway/terraform/gateway.tf](./4-mcp-gateway/terraform/gateway.tf)

This takes incoming requests using MCP and then invokes the Lambda with the incoming request as Lambda context.
Then it returns the response to the party making the MCP request.

### SSM:
[./4-mcp-gateway/terraform/ssm.tf](./4-mcp-gateway/terraform/ssm.tf)

This stores the MCP Gateway's URL so the agent(or other agents) knows where to point the MCP requests at.
## Stage 5 - Skills:
Directory: [./5-skills](./5-skills)

In this stage we can add some basic skills that the Agent can pull from. 
Skills separate out task-specific information from the main system prompts to keep the context window small and focused until the time comes to perform the specific task.
### Infrastructure:



```terraform
 skill {
    s3 {
      uri = "s3://${aws_s3_bucket.diagrams.bucket}/skills/poem/"
    }
  }
```


### Talking Points:
- [ ] Prompt "Use your poem skill to write something fun"




## Stage 6 - Code Interpreter:
Directory: [6-code-interpreter](6-code-interpreter)

WARNING: This is the most experimental stage and the results vary wildly based on the models you use. 

In this stage we give the agent an [Agent Skill](https://www.anthropic.com/news/skills) - a packaged folder of instructions (and optionally scripts) that teaches it a specific capability - alongside a sandboxed `agentcore_code_interpreter` tool to actually run those scripts. The skill used here, `terraform-diagram`, is one we wrote ourselves: it reads a directory of `.tf` files, produces a [Mermaid](https://mermaid.js.org/) dependency diagram of its resources, data sources, and modules, renders that diagram to a PNG, and uploads it to S3 - responding with a presigned URL to the image.

### Infrastructure:

The main codeblock to add is:
```terraform
tool {
    type = "agentcore_code_interpreter"
    name = "code_interpreter"

    config {
      agentcore_code_interpreter {
        code_interpreter_arn = aws_bedrockagentcore_code_interpreter.diagram_renderer.code_interpreter_arn
      }
    }
}
skill {
    s3 {
      uri = "s3://${aws_s3_bucket.diagrams.bucket}/skills/terraform-diagram/"
    }
}
```
[./5-skills/terraform/main.tf](./5-skills/terraform/main.tf)

### Custom Evaluator:
```
resource "aws_bedrockagentcore_evaluator" "terraform_diagram_skill" {
  evaluator_name = "terraform_diagram_skill_eval"
  level          = "TRACE"

  evaluator_config {
    llm_as_a_judge {
      instructions = "..." # see file for the full PASS/PARTIAL/FAIL rubric

      rating_scale {
        categorical { label = "PASS" ... }
        categorical { label = "PARTIAL" ... }
        categorical { label = "FAIL" ... }
      }

      model_config {
        bedrock_evaluator_model_config {
          model_id = "us.amazon.nova-2-lite-v1:0"
        }
      }
    }
  }
}
```
[./5-skills/terraform/evaluator.tf](./5-skills/terraform/evaluator.tf)



### Talking Points:
- [ ] "Draw me a network diagram of this Terraform https://github.com/schematical/sc-terraform/tree/main/modules/lambda-service."
- [ ] Follow the PNG link it responds with - it's a real, presigned S3 URL good for an hour.

## Clean Up:
Be sure to run `terraform destroy` in each of the respective terraform directories once you are done with them to spin down the infrastructure.
`

## Extra:

### Exporting as a deployable Strands runtime agent:
```bash 
npm install @aws/agentcore
./node_modules/.bin/agentcore create
cd {your project dir}
./node_modules/.bin/agentcore export harness --arn arn:aws:bedrock-agentcore:us-east-1:368590945923:harness/schematical_demo_stage5_harness-yPZVhWnFZb
```

### AgentCore Runtime vs Harness:
Runtime lets you bring your own code to the inner workings of an agent harness.

For most beginners if you want to use AgentCore I suggest sticking with harness unless you want to really be platform-agnostic, in which case probably don't use AgentCore.


### Extra Cost Management:
- [ ] https://us-east-1.console.aws.amazon.com/costmanagement/home?region=us-east-1#/cost-explorer?chartStyle=STACK&costAggregate=netUnblendedCost&endDate=2026-08-31&excludeForecasting=true&filter=%5B%7B%22dimension%22:%7B%22id%22:%22Service%22,%22displayValue%22:%22Service%22%7D,%22operator%22:%22INCLUDES%22,%22values%22:%5B%7B%22value%22:%22Amazon%20Bedrock%22,%22displayValue%22:%22Bedrock%22%7D%5D%7D%5D&futureRelativeRange=CUSTOM&granularity=Daily&groupBy=%5B%22Service%22%5D&historicalRelativeRange=CUSTOM&isDefault=true&reportMode=STANDARD&reportName=New%20cost%20and%20usage%20report&showOnlyUncategorized=false&showOnlyUntagged=false&startDate=2026-08-01&usageAggregate=undefined&useNormalizedUnits=false
- [ ] https://schematical.com/book


## Have More questions?
Feel free to connect
- [Schematical.com](https://schematical.com)
- [Free Resources](https://schematical.com/free)
- [LinkedIn](https://www.linkedin.com/in/schematical)
- [YouTube](https://www.youtube.com/schematical)
- [Discord](https://discord.gg/zUEacFT)


https://llmcamp.com/100days/agentmemory




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



