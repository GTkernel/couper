FROM alpine:latest

# build intial apk binary cache and install iperf3
RUN apk add --no-cache iperf3 iputils tc

# Expose the default iperf3 server ports
EXPOSE 5201/tcp 5201/udp

CMD ["iperf3", "-s"]
