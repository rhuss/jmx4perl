## Jmx4Perl Tools 1.12

This Docker image is intended to provided an easy access to the [Jmx4Perl](https://metacpan.org/pod/distribution/jmx4perl) tools, i.e.

* [**jmx4perl**](https://metacpan.org/pod/distribution/jmx4perl/scripts/jmx4perl) is a command line tool for one-shot querying a Jolokia agent. It is perfectly suited for shell scripts.
* [**j4psh**](https://metacpan.org/pod/distribution/jmx4perl/scripts/j4psh) is a readline based, JMX shell with coloring and command line completion. You can navigate the JMX namespace like directories with `cd` and `ls`, read JMX attributes with `cat` and execute operations with `exec`. 
* [**jolokia**](https://metacpan.org/pod/distribution/jmx4perl/scripts/jolokia) is an agent management tool which helps you in downloading Jolokia agents of various types (war, jvm, osgi, mule) and versions. It also knows how to repackage agents e.g. for enabling security with the war agent by inplace modification of the web.xml descriptor. 
* [**check_jmx4perl**](https://metacpan.org/pod/distribution/jmx4perl/scripts/check_jmx4perl) is a full featured Nagios plugin.

Please refer to the upstream tool documentation for details. 

Examples:

```shell
# Get some basic information of the server
docker run --rm -it jolokia/jmx4perl \
       jmx4perl http://localhost:8080/jolokia

# Download the current jolokia.war agent
docker run --rm -it -v `pwd`:/jolokia jolokia/jmx4perl \
       jolokia

# Start a JMX shell. "tomcat" is defined in ~/.j4p/jmx4perl.config
docker run --rm -it -v ~/.j4p:/root/.j4p jolokia/jmx4perl \
       j4psh tomcat
```

In these examples we mounted some volumes:

* If you put your server definitions into `~/.j4p/jmx4perl.config` you can use them by mounting this directory as volume with `-v ~/.j4p:/root/.j4p`. 
* For the management tool `jolokia` it is recommended to mount the local directory with `-v $(pwd):/jolokia` so that downloaded artefacts are stored in the current host directory. (Note for boot2docker users: This works only when you are in a directory below you home directory)

To simplify the usage, the following aliases are recommended:

```
alias jmx4perl="docker run --rm -it -v ~/.j4p:/root/.j4p jolokia/jmx4perl jmx4perl"
alias jolokia="docker run --rm -it -v `pwd`:/jolokia jolokia/jmx4perl jolokia"
alias j4psh="docker run --rm -it -v ~/.j4p:/root/.j4p jolokia/jmx4perl j4psh"
```
