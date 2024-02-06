FROM scratch
COPY hello-world /usr/bin/hello-world
#RUN chmod +x /usr/bin/hello-world
ENTRYPOINT ["/usr/bin/hello-world"]
