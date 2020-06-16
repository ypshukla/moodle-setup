# web_setup.sh
It will install Moodle with basic components

# Compatibility
It has been tested on CentOS 7

# How to use
Run web_setup.sh as root

# Post installation tasks
1) Secure Database by strong password
2) SSL for web server (we recommend https://letsencrypt.org/)
3) Plan for HA/Scalable deployment architecture
4) Install Unoconv and LibreOffice (converting documents into pdf)
5) Configure caching appropriately for both sessions and application
6) Configure ClamAV (anti virus)
7) Configure Solr (global search functionality)
8) Configure external email server (we recommend AWS SES)
9) Plan and deploy backup and disaster recovery
10) [optional] Setup Analytics (https://docs.moodle.org/35/en/Analytics)
11) [optional] Move data directory to S3 (https://moodle.org/plugins/tool_objectfs)

# References
1) https://github.com/aws-samples/aws-refarch-moodle
2) https://github.com/Azure/Moodle
