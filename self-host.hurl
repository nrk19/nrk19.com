#
# Test self-hosting assignment.
#
# Usage:
#
#     hurl --test --variable site=domain self-host.hurl
#
# Example:
#
#     hurl --test --variable site=example.com self-host.hurl
#
# Author: Fernando Raya
# Email: fraya@ieszaidinvergeles.org
#

# Index page exists
GET https://{{site}}/
HTTP 200

# Logo exists
GET https://{{site}}/logo.png
HTTP 200

# Administration
GET https://{{site}}/admin
[BasicAuth]
admin: asir

# Status
GET https://{{site}}/status
[BasicAuth]
sysadmin: risa

# Grafana auth
GET https://{{site}}/grafana
[BasicAuth]
sysadmin: risa