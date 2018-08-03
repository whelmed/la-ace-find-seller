const vision = require('@google-cloud/vision');
const Storage = require('@google-cloud/storage');
const database = require('./database');

/**
 * Triggered from a message on a Cloud Pub/Sub topic.
 *
 * @param {!Object} event Event payload and metadata.
 * @param {!Function} callback Callback function to signal completion.
 */
exports.imageParser = (event, callback) => {
  const pubsubMessage = event.data;
  const item = Buffer.from(pubsubMessage.data, 'base64').toString();
  const jsonItem = JSON.parse(item);

  // For reference, found this here: https://stackoverflow.com/questions/1053902/how-to-convert-a-title-to-a-url-slug-in-jquery#1054862
  function slugify(string) {
    return string
      .toString()
      .trim()
      .toLowerCase()
      .replace(/\s+/g, "-")
      .replace(/[^\w\-]+/g, "")
      .replace(/\-\-+/g, "-")
      .replace(/^-+/, "")
      .replace(/-+$/, "");
  }

  function labelDetection(db, instanceId, tableId, item, cb) {
    console.log('Attempting to perform label detection');
    const request = {
      image: {
        content: item.photo
      },
      features: [
        { type: "LOGO_DETECTION" },
        { type: "WEB_DETECTION" },
        { type: "LABEL_DETECTION" }
      ]
    };
    const client = new vision.ImageAnnotatorClient();

    client
      .annotateImage(request)
      .then(response => {
        const labels = response[0].labelAnnotations;
        const web = response[0].webDetection;
        const allLabels = Object.assign(labels, web.bestGuessLabels);

        // Now that we have the results, we can remove the image buffer from the item.
        delete jsonItem.photo; // No reason to save this into Bigtable. We just need the name so we can reference it in its bucket.

        db.saveToBigtable(instanceId, tableId, slugify(web.bestGuessLabels[0].label), item, allLabels, function (err) {
          if (err) {
            return cb(err);
          }
          else {
            return cb();
          }
        });

      })
      .catch(err => {
        return cb(err);
      });
  };


  function saveToStorage(imgContents, bucketName, fileName, fileType, cb) {
    console.log(`Attempting to save img to bucket with name: ${bucketName}`);
    const storage = new Storage();

    const bucket = storage.bucket(bucketName);
    const file = bucket.file(fileName);

    file.save(imgContents, {
      contentType: fileType,
    })
      .then(response => {
        return cb();
      }).catch(err => {
        return cb(err);
      });

  }



  saveToStorage(Buffer.from(jsonItem.photo, 'base64'), process.env.CLOUD_STORAGE_BUCKET, jsonItem.fileName, jsonItem.fileType, function (err) {
    if (err) {
      console.error(err);
      return callback(err);
    }

    // Since we've saved the image, let's now use Cloud Vision to check the labels and save the results to Bigtable.
    labelDetection(database, process.env.BIGTABLE_INSTANCE_ID, process.env.BIGTABLE_TABLE_ID, jsonItem, function (err) {
      if (err) {
        console.error(err);
        return callback(err);
      }
      else {
        return callback();
      }
    });
  });

};


