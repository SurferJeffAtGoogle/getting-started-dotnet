# Copyright (c) 2019 Google LLC.
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.


$projectId = gcloud config get-value project
$projectNumber = gcloud projects describe $projectId --format="get(projectNumber)"
$serviceAccount = "$projectNumber-compute@developer.gserviceaccount.com"
$keyRingId = "sessions-app"
$keyId = "data-protection-key"
$bucketName = "$projectId-bucket"
$region = "us-central1"

# Check to see if the key ring already exists.
$keyRingName = "projects/$projectId/locations/global/keyRings/$keyRingId" 
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
$keyName = "$keyRingName/cryptoKeys/$keyId"
$matchingKey = (gcloud kms keys list --format json --location global `
    --keyring $keyRingId --filter="$keyName" | ConvertFrom-Json).name
if ($matchingKey) {
    Write-Host "The key $matchingKey already exists."
} else { 
    # Create the new key.
    Write-Host "Creating new key $keyId..."
    gcloud kms keys create $keyId --location global --keyring $keyRingId --purpose=encryption
}

# Give the cloud run service account permission encrypt and decrypt with the
# key ring.
foreach ($role in "roles/cloudkms.cryptoKeyDecrypter", 
    "roles/cloudkms.cryptoKeyEncrypter") {
    Write-Host "Adding role $role to $serviceAccount for $keyRingName."
    gcloud kms keyrings add-iam-policy-binding $keyRingName `
        --member serviceAccount:$serviceAccount --role $role | Write-Host    
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
