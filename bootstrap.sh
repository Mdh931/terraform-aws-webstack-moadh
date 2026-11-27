#!/bin/bash
set -euo pipefail

dnf install -y nginx

if SECRET=$(aws ssm get-parameter --region "${region}" --name "${secret_parameter_name}" --with-decryption --query Parameter.Value --output text); then
  ETAT="oui (empreinte $(printf '%s' "$SECRET" | sha256sum | cut -c1-8))"
else
  ETAT="non"
fi
unset SECRET

cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html lang="fr">
<head><meta charset="utf-8"><title>${project} ${environment}</title></head>
<body>
<h1>${app_message}</h1>
<p>Environnement : <strong>${environment}</strong></p>
<p>Instance : $(hostname)</p>
<p>Secret chargé : $ETAT</p>
</body>
</html>
EOF

systemctl enable --now nginx
