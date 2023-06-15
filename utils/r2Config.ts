import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3"

import "dotenv/config"

const CF_ENVIRONMENT = process.env.CF_ENVIRONMENT || ""
const CF_ACCESS_KEY = process.env.CF_ACCESS_KEY || ""
const CF_SECRET_KEY = process.env.CF_SECRET_KEY || ""
const CF_BUCKET_NAME = process.env.CF_BUCKET_NAME || ""
const CF_ENDPOINT = `https://${process.env.CF_ACCOUNT_ID || ""}.r2.cloudflarestorage.com`
const r2 = new S3Client({
  region: "auto",
  endpoint: CF_ENDPOINT,
  credentials: {
    accessKeyId: CF_ACCESS_KEY,
    secretAccessKey: CF_SECRET_KEY,
  },
})

export const uploadConfigToR2 = async (name: string, address: string) => {
  const config = {}

  var buf = Buffer.from(JSON.stringify(Object.assign(config, { [name]: address })))

  var data = {
    Bucket: CF_BUCKET_NAME,
    Key: `config-${CF_ENVIRONMENT}-${name}.json`,
    Body: buf,
    ContentEncoding: "base64",
    ContentType: "application/json",
    ACL: "public-read",
  }

  const cmd = new PutObjectCommand(data)

  return await r2.send(cmd)
}
