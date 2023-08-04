# synology-cert-deploy
**Synology Certificate Deployer**

An automated tool for easy TLS certificate deployment on Synology DSM. Takes private key and full certificate chain files as input. Detects deployment locations, and services and packages requiring restart. Streamlines activation of a custom TLS certificate, assuming the presence of a default certificate (often Synology's self-signed certificate).

## Usage

```
synology-cert-deploy.sh [OPTION]
```
```
OPTION:

    -f, --force     forced key/certificate/chain/fullchain deployment
    -h, --help      show this help
    -n, --dry-run   perform a trial run (no actual changes will be applied, 
                    even with -f, --force enabled)
```

## Instructions

Before running the script, please edit the `SCRIPT CONFIG` section and provide the following information:

1. Private Key Location:
      
   Set the variable `new_key` to the location of the new private key you want to deploy. 
   
   Example:
   
   ```
   new_key="/path/to/your/privkey.pem"
   ```

2. Full Certificate Chain Location:
      
   Set the variable `new_fullchain` to the location of the file containing the full certificate chain (server certificate and intermediate certificates). 
   
   Example:
   
   ```
   new_fullchain="/path/to/your/fullchain.pem"
   ```

3. Services and Packages to Restart:
   If there are any additional services or packages that need to be restarted after the certificate deployment, add them to the `services_to_restart` or `packages_to_restart` array. Separate each service/package name with a space. 
   
   Example:
   
   ```
	services_to_restart=("service1" "service2")
	packages_to_restart=("package1" "package2")
	```

4. Services and Packages to Ignore:
      
   If there are any services or packages that should be ignored and not restarted when the script runs, add them to the `services_to_ignore` or `packages_to_ignore` array. Separate each service/package name with a space. 
   
   Example:

	```
	services_to_ignore=("service3" "service4")
	packages_to_ignore=("package3" "package4")
	```

**Note:** Please ensure the paths and names provided in the `SCRIPT CONFIG` section are accurate and valid for your Synology DSM system.

Once you have edited the `SCRIPT CONFIG` section with the appropriate values, you can proceed to run the script for automated TLS certificate deployment on Synology DSM.

Ensure you run the script with root privileges (using sudo) to avoid any permission issues during the certificate deployment process. For automated execution, consider setting up the script as a Scheduled Task in Task Scheduler to run as root once a week.

## Use Case

If you have your own out-of-band TLS certificate issuance / renewal workflow (e.g. [certobot](https://certbot.eff.org/) ), or you prefer not to expose your Synology DSM directly to the Internet, but still want to use a Let's Encrypt certificate, you can leverage `synology-cert-deploy.sh` to deploy your custom certificates.

Additionally, you have the option to use tools like [Caddy Web Server](https://caddyserver.com/) with or without a DNS provider (e.g, [Caddy Web Server with ACME-DNS Provider](https://github.com/timelordx/caddy-dns-acmedns)) inside Container Manager (Docker) of your Synology DSM for automated TLS certificate issuance and renewals.

Assuming you have the following Caddy configurations:

`docker-compose.yml`:

```
services:
  caddy:
    image: timelordx/caddy-dns-acmedns:latest
    container_name: caddy
    environment:
      - PUID=YOUR_UID
      - PGID=YOUR_GID
      - TZ=YOUR_TZ
    volumes:
      - /volume1/docker/caddy/etc/caddy:/etc/caddy:ro
      - /volume1/docker/caddy/config:/config
      - /volume1/docker/caddy/data:/data
      - /volume1/docker/caddy/logs:/logs
    network_mode: host
    restart: unless-stopped
```
`Caddyfile`:

```
example.com, *.example.com {

	tls {
		dns acmedns /path/to/acmedns-example.com.json
	}

	...
}
```
You can proceed to configure the `synology-cert-deploy.sh` script:

`SCRIPT CONFIG`:

```
new_key='/volume1/docker/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/wildcard_.example.com/wildcard_.example.com.key'
 new_fullchain='/volume1/docker/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/wildcard_.example.com/wildcard_.example.com.crt'
```

With the above configuration, the script will deploy a wildcard TLS certificate `*.example.com` to your Synology DSM.
