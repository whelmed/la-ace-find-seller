
AD_SERVICE_IP=$(gcloud compute forwarding-rules list --filter='name:"ads-service-forwarding-rules"' --format='value(IPAddress)')
PRODUCTS_SERVICE_IP=$(kubectl get svc -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')
FRONT_END_HOST=$(gcloud app describe --format='value(defaultHostname)')

cat > ../app/index.js << EOL
exports.index = (event, callback) => {
    res.status(200).send({
        "products": "http://$PRODUCTS_SERVICE_IP",
        "ads": "http://$AD_SERVICE_IP",
        "frontend": "http://$FRONT_END_HOST"
    });
};
EOL