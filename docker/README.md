## Jmx4Perl Tools 1.12

This Docker image is intended to provided an easy access to the
[Jmx4Perl](http://www.jmx4perl.org) Tools, i.e.

* **[jmx4perl](http://search.cpan.org/~roland/jmx4perl/scripts/jmx4perl)** -- Command line 
* **[j4psh](http://search.cpan.org/~roland/jmx4perl/scripts/j4psh)**
  -- JMX shell
* **[jolokia](http://search.cpan.org/~roland/jmx4perl/scripts/jolokia)**
  -- Jolokia agent management tool
* **[check_jmx4perl](http://search.cpan.org/~roland/jmx4perl/scripts/check_jmx4perl)**
  -- Send Jolokia Requests from the command line

Please refer to the upstream tool documentation for details. 

Examples:

````shell
# Get some basic information of the server
docker run --rm -it jolokia/jmx4perl jmx4perl http://localhost:8080/jolokia

# Download the current jolokia.war agent 
docker run --rm -it -v `pwd`:/jolokia jolokia/jmx4perl jolokia

# Start an interactive JMX shell, server "tomcat" is defined in ~/.j4p/jmx4perl.config
docker run --rm -it -v ~/.j4p:/root/.j4p jolokia/jmx4perl j4psh tomcat
````

If you put your server definitions into `~/.j4p/jmx4perl.config` you
can use them by volume mounting them with `-v
~/.j4p:/root/.j4p`. For the management tool `jolokia` it is
recommended to mount the local directory with `-v $(pwd):/jolokia` so
that downloaded artefacts are stored in the current host directory

To simplify the usage, the following shell setup can be used:

````shell
function j4p_docker {
  alias jmx4perl="docker run --rm -it -v ~/.j4p:/root/.j4p jolokia/jmx4perl jmx4perl"
  alias jolokia="docker run --rm -it -v `pwd`:/jolokia jolokia/jmx4perl jolokia"
  alias j4psh="docker run --rm -it -v ~/.j4p:/root/.j4p jolokia/jmx4perl j4psh"
}
````
