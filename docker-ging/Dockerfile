FROM centos:centos6

ENV API_UMBRELLA_VERSION 0.14.4-1~centos

# Install API Umbrella
RUN yum -y update; yum clean all
RUN yum -y install git 
RUN groupadd -r api-umbrella && \
useradd -r -g api-umbrella -s /sbin/nologin -d /opt/api-umbrella -c "API Umbrella user" api-umbrella
RUN git clone https://github.com/ging/api-umbrella.git
RUN chmod 775 -R ./api-umbrella
RUN cd ./api-umbrella && ./build/scripts/install_build_dependencies && ./configure && make && make install


# Define mountable directories
VOLUME ["/etc/api-umbrella", "/opt/api-umbrella/var/db", "/opt/api-umbrella/var/log"]

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Run the API Umbrella service
CMD ["api-umbrella", "run"]

