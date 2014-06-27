var crypto = require('crypto');

// params: dir, key, secret, expiration, bucket, acl, type, redirect
module.exports = function(params) {

  var date = new Date();
  var s3Policy = {
    expiration: params.expiration,
    conditions: [
      ["starts-with", "$key", params.dir],
      {bucket: params.bucket},
      {acl: params.acl},
      ['starts-with', "$Content-Type", params.type]
    ]
  }

  // stringify and encode policy
  var stringPolicy = JSON.stringify(s3Policy);
  var base64Policy = Buffer(stringPolicy, 'utf-8').toString('base64');

  // sign the base64 encoded policy
  var signature = crypto.createHmac('sha1', params.secret)
    .update(new Buffer(base64Policy, 'utf-8'))
    .digest('base64');


  return {
    key:            params.dir+"${filename}",
    AWSAccessKeyId: params.key,
    signature:      signature,
    policy:         base64Policy,
    acl:            params.acl,
    'Content-Type': params.type
  };
}
