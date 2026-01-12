const { Schema, model } = require('mongoose');
const IncognitoSchema = Schema({
    de: {
        type: String,
        required: true
    },
    para: {
        type: String,
        required: true
    },
    incognito: {
        type: Boolean,
        default: false
    }
},
    {
        timestamps: true
    }
);

IncognitoSchema.method('toJSON', function () {
    const { _id, ...object } = this.toObject();
    return object;
})

module.exports = model('Incognito', IncognitoSchema);