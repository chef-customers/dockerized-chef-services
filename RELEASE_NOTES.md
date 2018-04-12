This document contains historical release notes from the last minor
release and prior.  The current release notes and subsequent patch
releases can be found [RELEASE\_NOTES.md](RELEASE_NOTES.md).

## 0.2.0 (2018-04-12)
  * Tested and validated with Chef Server 12.17.41 and Automate 1.8.38 
    NOTE: Set `$CHEF_SERVER_VERSION` and `$AUTOMATE_VERSION` repsectively to pull these verified versions from Dockerhub
  * Introduced a single control script `docker-chef.sh` so that start|stop and `/hab/sup` directory clearing functionality is consistent.
    NOTE: Please use this script as it is how we can better enforce desired behavior.
  * `automate-ctl` functionality is working and will be made available in the next release.
