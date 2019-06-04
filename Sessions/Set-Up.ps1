
$projectId = gcloud config get-value project
$keyRingId = "sessions-app"
$keyId = "data-protection-key"
$bucketName = "$projectId-bucket"
$region = "us-central1"

# Check to see if the key ring already exists.
$matchingKeyRing = (gcloud kms keyrings list --format json --location global `
    --filter="projects/$projectId/locations/global/keyRings/$keyRingId" | ConvertFrom-Json).name
if ($matchingKeyRing) {
    Write-Host "The key ring $matchingKeyRing already exists."
} else { 
    # Create the new key ring.
    Write-Host "Creating new key ring $keyRingId..." 
    gcloud kms keyrings create $keyRingId --location global
}

# Check to see if the key already exists
$keyName = "projects/$projectId/locations/global/keyRings/$keyRingId/cryptoKeys/$keyId"
$matchingKey = (gcloud kms keys list --format json --location global `
    --keyring $keyRingId --filter="$keyName" | ConvertFrom-Json).name
if ($matchingKey) {
    Write-Host "The key $matchingKey already exists."
} else { 
    # Create the new key.
    Write-Host "Creating new key $keyId..."
    gcloud kms keys create $keyId --location global --keyring $keyRingId --purpose=encryption
}

# Check to see if the bucket already exists.
$matchingBucket = (gsutil ls -b gs://$bucketName) 2> $null
if ($matchingBucket) {
    Write-Host "The bucket $bucketName already exists."
} else {
    # Create the bucket.
    gsutil mb -p $projectId gs://$bucketName
}

# Create the redis cache.
while ($true) {
    $redisCaches = gcloud redis instances list --region $region --format json | ConvertFrom-Json
    if ($redisCaches) 
    {
        $cache = $redisCaches[0]
        $name = $cache.name
        Write-Host "Using redis cache $name."
        break
    }
    gcloud redis instances create --region $region session-store
}

# Save settings to appsettings.json
$appsettings = Get-Content -Raw appsettings.json | ConvertFrom-Json
$appsettings.DataProtection.KmsKeyName = $keyName
$appsettings.DataProtection.Bucket = $bucketName
$appsettings.Redis.Configuration = $cache.host
ConvertTo-Json $appsettings | Out-File -Encoding utf8 -FilePath appsettings.json