FROM debian:bullseye-slim
 
RUN apt-get clean
# Delete index files we don't need anymore:
RUN rm -rf /var/lib/apt/lists/*
 
# Tell apt-get we're never going to be able to give manual feedback:
RUN export DEBIAN_FRONTEND=noninteractive
 
# Update the package listing, so we know what package exist:
#echo 'Doing apt-get update'
RUN apt-get update
 
# Install security updates:
RUN apt-get --yes upgrade
 
RUN apt-get update && apt-get --yes install --no-install-recommends apt-utils
RUN apt-get update && apt-get --yes install --no-install-recommends ser2net
RUN apt-get update && apt-get --yes install --no-install-recommends tzdata
 
# Delete cached files we don't need anymore
RUN apt-get clean
# Delete index files we don't need anymore:
RUN rm -rf /var/lib/apt/lists/*
 
RUN rm /etc/localtime
RUN ln -s /usr/share/zoneinfo/US/Eastern /etc/localtime
 
CMD [ "bash", "-c", "ser2net -d -l -l -c /etc/ser2net.yaml"]
