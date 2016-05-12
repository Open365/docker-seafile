#!/usr/bin/env node
/*
    Copyright (c) 2016 eyeOS

    This file is part of Open365.

    Open365 is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/


var CardHasher = function(crypto, stringify) {
	this.crypto = crypto || require('crypto');
	this.stringify = orderedStringify;
};

CardHasher.prototype.getHash = function(card) {
	var stringCard = this.stringify(card);
	var md5 = this.crypto.createHash('md5');
	var md5Updated = md5.update(stringCard);
	return md5Updated.digest('hex');
};

var ExpirationChecker = function() {

};

ExpirationChecker.prototype.check = function(card) {
	var now = Math.floor(Date.now() / 1000);
	return (card.expiration > now);
};

var orderedStringify = function(o, fn) {
	var props = [];
	var res = '{';
	for(var i in o) {
		props.push(i);
	}
	props = props.sort(fn);

	for(var i = 0; i < props.length; i++) {
		var val = o[props[i]];
		var type = types[whatis(val)];
		if(type === 3) {
			val = orderedStringify(val, fn);
		} else if(type === 2) {
			val = arrayStringify(val, fn);
		} else if(type === 1) {
			val = '"'+val+'"';
		}

		if(type !== 4)
			res += '"'+props[i]+'":'+ val+',';
	}

	return res.substring(res, res.lastIndexOf(','))+'}';
};

//orderedStringify for array containing objects
var arrayStringify = function(a, fn) {
	var res = '[';
	for(var i = 0; i < a.length; i++) {
		var val = a[i];
		var type = types[whatis(val)];
		if(type === 3) {
			val = orderedStringify(val, fn);
		} else if(type === 2) {
			val = arrayStringify(val);
		} else if(type === 1) {
			val = '"'+val+'"';
		}

		if(type !== 4)
			res += ''+ val+',';
	}

	return res.substring(res, res.lastIndexOf(','))+']';
}

//SORT WITHOUT STRINGIFICATION

var sortProperties = function(o, fn) {
	var props = [];
	var res = {};
	for(var i in o) {
		props.push(i);
	}
	props = props.sort(fn);

	for(var i = 0; i < props.length; i++) {
		var val = o[props[i]];
		var type = types[whatis(val)];

		if(type === 3) {
			val = sortProperties(val, fn);
		} else if(type === 2) {
			val = sortProperiesInArray(val, fn);
		}
		res[props[i]] = val;
	}

	return res;
};

//sortProperties for array containing objects
var sortProperiesInArray = function(a, fn) {
	for(var i = 0; i < a.length; i++) {
		var val = a[i];
		var type = types[whatis(val)];
		if(type === 3) {
			val = sortProperties(val, fn);
		} else if(type === 2) {
			val = sortProperiesInArray(val, fn);
		}
		a[i] = val;
	}

	return a;
};

//HELPER FUNCTIONS

var types = {
	'integer': 0,
	'float': 0,
	'string': 1,
	'array': 2,
	'object': 3,
	'function': 4,
	'regexp': 5,
	'date': 6,
	'null': 7,
	'undefined': 8,
	'boolean': 9
}

var getClass = function(val) {
	return Object.prototype.toString.call(val)
		.match(/^\[object\s(.*)\]$/)[1];
};

var whatis = function(val) {

	if (val === undefined)
		return 'undefined';
	if (val === null)
		return 'null';

	var type = typeof val;

	if (type === 'object')
		type = getClass(val).toLowerCase();

	if (type === 'number') {
		if (val.toString().indexOf('.') > 0)
			return 'float';
		else
			return 'integer';
	}

	return type;
};

var RequestParser = function()  {
};

RequestParser.prototype.getCard = function(request, cardType) {
	cardType = cardType || 'card';
	var CardType = cardType.charAt(0).toUpperCase() + cardType.slice(1);
	if (!request.headers || (!request.headers[cardType] && !request.headers[CardType])) {
		console.log('Invalid headers');
		return null;
	}

	var card = null;
	try {
		card = JSON.parse(request.headers[cardType] || request.headers[CardType]);
	} catch (err) {
		console.log('Invalid JSON in request.headers.card:', request.headers[cardType]);
		console.log(err);
	}

	return card;
};

RequestParser.prototype.getSignature = function(request, signatureType) {
	signatureType = signatureType || 'signature';
	var SignatureType = signatureType.charAt(0).toUpperCase() + signatureType.slice(1);
	if (!request.headers || (!request.headers[signatureType] && !request.headers[SignatureType])) {
		console.log('Invalid headers');
		return '';
	}

	return request.headers[signatureType] || request.headers[SignatureType];
};

var RsaVerifier = function(publicPem) {
	if(settings.keys.version == 1){
		this.publicPem = publicPem || new Buffer(settings.keys.publicPem, 'base64').toString("utf-8");
	} else if(settings.keys.version == 2) {
		if (settings.keys.publicPem === "" && !publicPem){
			console.log("Incorrect public key, please provide a valid one.");
		} else {
			this.publicPem = publicPem || new Buffer(settings.keys.publicPem, 'base64').toString("utf-8");
		}
	}
};

RsaVerifier.prototype.verify = function(hash, signature, verifierInjected) {
	this.verifier = verifierInjected || require('crypto').createVerify('RSA-SHA256');
	this.verifier.update(hash);
	return this.verifier.verify(this.publicPem, signature, 'base64');
};

var environment = process.env;
if (environment.EYEOS_RENEW_CARD_MINUTES_BEFORE_EXPIRATION !== undefined) {
	console.log("Using deprecated (and incorrect) setting EYEOS_RENEW_CARD_MINUTES_BEFORE_EXPIRATION.");
	console.log("Please use EYEOS_RENEW_CARD_SECONDS_BEFORE_EXPIRATION which uses the correct units.");

	environment.EYEOS_RENEW_CARD_SECONDS_BEFORE_EXPIRATION = environment.EYEOS_RENEW_CARD_MINUTES_BEFORE_EXPIRATION;
}
var settings = {
	EYEOS_DEVELOPMENT_MODE: environment.EYEOS_DEVELOPMENT_MODE === 'true' || false,
	validCardExpirationSeconds: parseInt(environment.EYEOS_EXPIRATION_CARD, 10) || (10 * 60 * 60), // 10 hours in seconds
	renewCardSecondsBeforeExpiration: parseInt(environment.EYEOS_RENEW_CARD_SECONDS_BEFORE_EXPIRATION, 10) || (30 * 60), //half hour in seconds,
	defaultDomain: environment.DEFAULT_DOMAIN || "open365.io",
	mongoInfo: {
		host: environment.EYEOS_AUTHENTICATION_MONGOINFO_HOST || 'mongo.service.consul',
		port: environment.EYEOS_AUTHENTICATION_MONGOINFO_PORT || 27017,
		db: environment.EYEOS_AUTHENTICATION_MONGOINFO_DB || 'eyeos'
	},
	server: {
		port: 4101,
		skipAuthentication: environment.EYEOS_AUTH_API_SERVER_SKIP_AUTH === 'true' || false
	},
	stompServer: {
		host: environment.EYEOS_VDI_SERVICE_USERQUEUE_HOST || 'rabbit.service.consul',
		port: environment.EYEOS_VDI_SERVICE_USERQUEUE_PORT || 61613,
		login: environment.EYEOS_BUS_MASTER_USER || 'guest',
		passcode: environment.EYEOS_BUS_MASTER_PASSWD || 'somepassword'
	},
	keys: {
		version: environment.EYEOS_AUTH_KEY_VERSION || 1,
		publicPem: environment.EYEOS_PUBLIC_PEM || ""
	}
};

var EYEOS_DEVELOPMENT_MODE = settings.EYEOS_DEVELOPMENT_MODE;

var ValidateEyeosCard = function (cardHasher, rsaVerifier, expirationChecker) {
	this.cardHasher = cardHasher || new CardHasher();
	this.rsaVerifier = rsaVerifier || new RsaVerifier();
	this.expirationChecker = expirationChecker || new ExpirationChecker();
};

if (EYEOS_DEVELOPMENT_MODE) { // in development mode all cards are true, just check mandatory params
	ValidateEyeosCard.prototype.validate = function(card, signature) {
		if (!card || !signature) {
			return false;
		}
		return true;
	};
} else {
	ValidateEyeosCard.prototype.validate = function (card, signature) {
		if (!card || !signature) {
			return false;
		}
		var valid = this.expirationChecker.check(card);
		if (!valid) {
			return false;
		}
		var hash = this.cardHasher.getHash(card);
		return this.rsaVerifier.verify(hash, signature);
	};
}

if (process.argv.length != 3) {
	console.error("Invalid parameters", process.argv);
	process.exit(1);
}

var jsonString = process.argv[2].replace(/#/g, '"');
var data = JSON.parse(jsonString);
console.log("Received", data);
var request = {
	headers: {
		minicard: JSON.stringify(data.c),
		minisignature: data.s
	}
};

var EyeosAuth = function(validateEyeosCard, requestParser) {
	this.validateEyeosCard = validateEyeosCard || new ValidateEyeosCard();
	this.requestParser = requestParser || new RequestParser();
};

EyeosAuth.prototype.verifyRequestWithMini = function(request) {
	var card = this.requestParser.getCard(request, 'minicard');
	var signature = this.requestParser.getSignature(request, 'minisignature');
	return this.validateEyeosCard.validate(card, signature);
};

var auth = new EyeosAuth();
if (auth.verifyRequestWithMini(request)) {
	console.log("Sucessfully Authenticated");
	process.exit(0);
} else {
	console.log("Authentication failed");
	process.exit(1);
}
