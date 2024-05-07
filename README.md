# Taitaja 2024 - Skill 205 - IT Specialist

This repository contains necessary files to deploy the [test project's](205_Taitaja2024_Pilvipalvelut_Finaali.pdf) hoster and competitor preparation infrastructure to Azure. 

## Pre-requirements
- Azure subscription
- Open AI Service whitelisting from Microsoft (https://aka.ms/oai/access)

## Hoster

Hoster side contains

- Public DNS Zone
- Storage account to provide necessary files for web page
- Optional script, which creates necessary user accounts for competitors
- [Instructions](hoster_instructions.pdf) how to complete hoster side deployment after deployment

### Deploy hoster

To deploy hoster side Azure resources, click the button below and fill necessary parameter values.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fdev.azure.com%2Forgname%2Fprojectname%2F_apis%2Fgit%2Frepositories%2Freponame%2Fitems%3FscopePath%3D%2freponame%2fazuredeploy.json%26api-version%3D6.0)


## Competitor

Competitor side contains:

- Resource group for given number of competitors
- PowerShell-script that should be migrated towards the cloud in test project (source server not included)
- [Instructions](competitor_instructions.pdf) how to complete competitor side deployment

### Deploy competitor

To deploy competitor side Azure resources, click the button below and fill necessary parameter values.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fdev.azure.com%2Forgname%2Fprojectname%2F_apis%2Fgit%2Frepositories%2Freponame%2Fitems%3FscopePath%3D%2freponame%2fazuredeploy.json%26api-version%3D6.0)

## Contribution

Repository was created during the preparation of Taitaja 2024 Cloudservice test project and it **is not planned to update** after the competition. After the cloud service test project is ended and the protest time is over, the repository visibility is changed to public. Feel free to use this repository for teaching and training. 