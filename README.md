# Taitaja 2024 - Skill 205 - IT Specialist

This repository contains necessary files to deploy the [test project's](205_Taitaja2024_Pilvipalvelut_Finaali.pdf) hoster and competitor preparation infrastructure to Azure. 

## Pre-requirements
- Azure subscription with owner permissions
- Open AI Service whitelisting from Microsoft (https://aka.ms/oai/access)
- Public DNS name that can be used on hoster side

## Installation steps
1. Run hoster side deployment. Remember to take output variables for website hostin *temp_site.zip* and root dns zone resource id
2. Create csv file by creating user accounts with a script or manually gathering UPN's and objectId's. If using script to create user accounts, password of account are stored also in csv-file.
3. Run competitor infrastructure creation script

## Hoster

Hoster side contains

- Public DNS Zone
- Storage account to provide necessary files for web page
- [Instructions](hoster_instructions.pdf) how to complete hoster side deployment after deployment

### Deploy hoster

To deploy hoster side Azure resources, click the button below and fill necessary parameter values.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fdev.azure.com%2Forgname%2Fprojectname%2F_apis%2Fgit%2Frepositories%2Freponame%2Fitems%3FscopePath%3D%2freponame%2fazuredeploy.json%26api-version%3D6.0)


## Competitor

Competitor side contains:

- Script, which creates necessary user accounts for competitors. You can also create this manually.
- Resource group for given number of competitors
- DNS zone for each competitor and ns-records to root dns-zone
- PowerShell-script that should be migrated towards the cloud in test project (source server not included)
- [Instructions](competitor_instructions.pdf) how to complete competitor side deployment

### Deploy competitor

To deploy competitor side Azure resources, create CSV-file and create infrastructure by script **Create-CompetitionInfrastructure.ps1**.

## Contribution

Repository was created during the preparation of Taitaja 2024 Cloudservice test project and it **is not planned to update** after the competition. After the cloud service test project is ended and the protest time is over, the repository visibility is changed to public. Feel free to use this repository for teaching and training. 