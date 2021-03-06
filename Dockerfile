#use armv7hf compatible base image
FROM balenalib/armv7hf-debian:buster-20191223

#dynamic build arguments coming from the /hook/build file
ARG BUILD_DATE
ARG VCS_REF

#metadata labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF

#copy files
COPY "./init.d/*" /etc/init.d/ 
COPY "./driver/*" "./driver/includes/" "./firmware/*" /tmp/

#enable building ARM container on x86 machinery on the web (comment out next line if built on Raspberry)
RUN [ "cross-build-start" ]

#version
ENV IPA_NETPI_CODESYS_NETX 1.0.0

#execute all commands as root
USER root

#labeling
LABEL maintainer="jcj@ipa.fraunhofer.de" \
      version=$IPA_CODESYS_NETX \
      description="CODESYS Control with netX based TCP/IP network interface"

#copy files
COPY "./driver/*" "./firmware/*" /tmp/
	  
#environment variables
ENV USER=pi
ENV PASSWD=raspberry

#do installation
RUN apt-get update  \
    	&& apt-get install -y openssh-server build-essential ifupdown isc-dhcp-client net-tools psmisc usbutils nano \
	&& mkdir /var/run/sshd \
    	&& useradd --create-home --shell /bin/bash pi \
    	&& echo $USER:$PASSWD | chpasswd \
    	&& adduser $USER sudo \
    	&& echo $USER " ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd \
# create some necessary files for CODESYS
    	&& touch /usr/bin/modprobe \
    	&& chmod +x /usr/bin/modprobe \
    	&& mkdir /etc/modprobe.d \
    	&& touch /etc/modprobe.d/blacklist.conf \
    	&& touch /etc/modules \
#install netX driver and netX ethernet supporting firmware
    	&& dpkg -i /tmp/netx-docker-pi-drv-2.0.1-r0.deb \
    	&& dpkg -i /tmp/netx-docker-pi-pns-eth-3.12.0.8.deb \
#compile netX network daemon that creates the cifx0 ethernet interface
    	&& echo "Irq=/sys/class/gpio/gpio24/value" >> /opt/cifx/plugins/netx-spm/config0 \
    	&& cp /tmp/*.h /usr/include/cifx \
    	&& cp /tmp/cifx0daemon.c /opt/cifx/cifx0daemon.c \
    	&& gcc /opt/cifx/cifx0daemon.c -o /opt/cifx/cifx0daemon -I/usr/include/cifx -Iincludes/ -lcifx -pthread \
#clean up
    	&& rm -rf /tmp/* \
    	&& apt-get remove build-essential \
    	&& apt-get -yqq autoremove \
    	&& apt-get -y clean \
    	&& rm -rf /var/lib/apt/lists/*
	
#copy file
COPY "./fonts/*" /home/$USER/.fonts/
	
#do ports
EXPOSE 22 1217 4840

#do entrypoint
ENTRYPOINT ["/etc/init.d/entrypoint.sh"]

#set STOPSGINAL
STOPSIGNAL SIGTERM

#stop processing ARM emulation (comment out next line if built on Raspberry)
RUN [ "cross-build-end" ]
