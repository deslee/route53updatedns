FROM python:3.7.2-stretch
RUN apt-get update
RUN apt-get install -y dnsutils
RUN pip install awscli
WORKDIR /script
ADD update-route53.sh .
ENTRYPOINT ["./update-route53.sh"]