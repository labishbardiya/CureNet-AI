const { v4: uuidv4 } = require('uuid');

/**
 * Generates a standard UUID specifically structured to be ABDM compliant
 * for use as a careContext.referenceNumber or general tracking ID.
 */
const generateId = () => {
    return uuidv4();
};

module.exports = { generateId };
