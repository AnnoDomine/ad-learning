# LearningSteps Origins
 
## Welcome to the Cloud! ☁️

It is time to take your code off localhost and into the real world. In this project, you will act as a Cloud Architect to deploy the LearningSteps API to a secure, production-ready 2-tier architecture on Microsoft Azure.

> You have 2 weeks to complete this project.

Don't panic! Over the next two weeks, we will deep-dive into Azure Administration, covering every networking, security, and compute concept required to build this architecture.

- For the bold: Start researching immediately and treat this as a real-world scenario where you must figure it out on the fly.
- For the methodical: Build your infrastructure piece-by-piece as we unlock new topics in the course.

## What is LearningSteps?

![Screenshot 2025-11-27 at 14.10.43 (1)](https://cybersteps-prod-uploads.fra1.digitaloceanspaces.com/assets/4a/4aa433be71213e8a918218110927dbd96bdff2045f248185fe8f6b18cf04dbaf.png)

LearningSteps is a Python FastAPI application backed by a PostgreSQL database, designed to help users track their daily learning journey. It provides a RESTful API to Create, Read, Update, and Delete (CRUD) journal entries.

# LearningSteps - A Companion for the Journey

> This deployment is just the beginning. LearningSteps will serve as our core platform throughout the curriculum, evolving alongside your skills. In future modules, we will return to this architecture to implement:

- Automated Deployments (CI/CD): Replacing manual steps with robust pipelines.
- Observability: Implementing monitoring, logging, and alerting stacks.
- Advanced Security: Hardening the cloud environment against threats.
- Container Orchestration: Scaling the application for high availability.

Build it well now, and you will have a solid foundation for the advanced challenges ahead!

## Challenge Overview

> Create a secure 2-tier architecture on Azure:

- Tier 1: FastAPI application server (internet-accessible)
- Tier 2: PostgreSQL database server (private, secure)

## Learning Objectives

![Screen2](https://cybersteps-prod-uploads.fra1.digitaloceanspaces.com/assets/43/431509916e970621ab3a529580843221bfcad33fd81c7770ff8c2ba2fb299fb8.png)

- Design secure cloud networking with public/private subnets in Azure
- Implement Network Security Groups (NSGs) following least privilege principles
- Configure remote database access securely
- Deploy a production-ready multi-tier application
- Manage environment variables and application secrets in a cloud environment

## Prerequisites & Setup

> Before starting the infrastructure deployment, you must prepare the application code.

### Get the Code

Clone the repository:

- Repo URL: https://github.com/CyberstepsDE/learningsteps

### Choose Your Path

> You have two options for the codebase:

- The Developer Challenge: Use the main branch. This version contains incomplete development tasks (TODOs). You will need to finish the code to get the API working locally before deploying.
- The Reference Implementation: Switch to the reference branch (Link). This branch has all tasks completed and is ready for immediate deployment if you want to focus purely on the infrastructure side.

### Cloud Requirements

- Microsoft Azure account with appropriate permissions (Active Subscription)

## Your Mission

### Design Your Architecture

> Research and plan your cloud infrastructure:

- How will you separate public and private resources? (e.g., VNETs, Subnets)
- What networking components do you need? (e.g., Network Interfaces, Public IPs)
- How will you secure communication between the FastAPI app and PostgreSQL? (e.g., NSGs)

### Prepare the Application

- If you chose the Developer Challenge, complete the code tasks in the main branch first. Verify the API works locally.
- If you chose the Reference Implementation, verify you can run the application locally or containerize it successfully.
- Prepare your environment variables (.env) for the cloud production environment.

### Deploy the API Server

> Set up your application server in the public tier:

- Choose appropriate compute resources
- Deploy your Journal API application
- Configure secure access and networking

### Deploy the Database Server

> Set up PostgreSQL in the private tier:

- Ensure it's not directly accessible from the internet
- Configure it to accept connections from your API server
- Implement proper security measures

### Test Your Deployment

> Validate your architecture:

- All API endpoints work correctly.
- The Database is unreachable from the public internet.
- Data persists between server restarts.

## Success Criteria

Your deployment succeeds when you can demonstrate:

✅ LearningSteps API is accessible via a public IP or Domain.  
✅ Database is strictly internal (cannot connect via public internet).  
✅ All CRUD operations (creating steps, updating progress) work via API endpoints.  
✅ Data persists even if the API server is rebooted or redeployed.  
✅ Network Security Groups are tightly scoped (Least Privilege).  

## Document Your Learning

Create a technical writeup covering:

- Architecture Diagram: Visualizing your 2-tier Azure setup.
- Security Decisions: Why did you configure your NSGs/firewalls this way?
- Challenges: Any issues connecting the tiers?
- Key Learnings: What did you learn about Azure networking?

### Remember

This is about understanding cloud patterns, not following a recipe. Research, experiment, and learn from the journey. Whether you fix the code yourself or use the reference implementation, the goal is a secure, working cloud deployment.
