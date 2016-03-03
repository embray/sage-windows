# To use this Dockerfile efficiently run
# docker run -v /var/run/docker.sock:/var/run/docker.sock \
#     $(docker build -f Dockerfile.windows .)

FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

RUN dpkg --add-architecture i386
RUN sed -i "s/main/main contrib non-free/" etc/apt/sources.list


# add the docker PPA
RUN apt-get update && apt-get install -yq apt-transport-https
RUN apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list

RUN apt-get update && apt-get install -yq wine curl unrar unzip bzip2 docker-engine

# innosetup
RUN mkdir innosetup && \
    cd innosetup && \
    curl -fsSL -o innounp045.rar "https://downloads.sourceforge.net/project/innounp/innounp/innounp%200.45/innounp045.rar?r=&ts=1439566551&use_mirror=skylineservers" && \
    unrar e innounp045.rar

RUN cd innosetup && \
    curl -fsSL -o is-unicode.exe http://files.jrsoftware.org/is/5/isetup-5.5.8-unicode.exe && \
    wine "./innounp.exe" -e "is-unicode.exe"

# installer components
ENV INSTALLER_VERSION 1.0
ENV DOCKER_TOOLBOX_VERSION 1.10.2
#ENV MIXPANEL_TOKEN c306ae65c33d7d09fe3e546f36493a6e

# docker images
# Mount a local directory as a volume to /images when running this image to avoid 
# having to recreate image archives (time consuming!)
RUN mkdir /images

RUN mkdir /bundle
WORKDIR /bundle
RUN curl -fsSL -o DockerToolbox.exe "https://github.com/docker/toolbox/releases/download/v${DOCKER_TOOLBOX_VERSION}/DockerToolbox-${DOCKER_TOOLBOX_VERSION}.exe"

# Add installer resources
COPY windows /installer

WORKDIR /installer
RUN rm -rf /tmp/.wine-0/

# Sage image components and Inno Setup options
ARG SAGE_IMAGE_REPO=sagemath/sagemath-jupyter
ARG SAGE_IMAGE_TAG=latest
ARG INNO_FLAGS
ENV SAGE_IMAGE_REPO ${SAGE_IMAGE_REPO}
ENV SAGE_IMAGE_TAG ${SAGE_IMAGE_TAG}
ENV SAGE_IMAGE_FULL ${SAGE_IMAGE_REPO}:${SAGE_IMAGE_TAG}
ENV INNO_FLAGS ${INNO_FLAGS}

CMD ./build
