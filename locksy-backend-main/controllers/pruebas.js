const { response } = require('express');

const pruebaDeyner = async (req, res = response) => {
    var codigos = [];

    function generateNum(min, max) {
        return Math.floor(Math.random() * (max - min + 1) + min);
    }

    function generateStr() {
        var letras = 'abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/+=';
        var cant = letras.length;
        var rng = generateNum(0, letras.length - 1);
        return letras.substring(rng, rng + 1);
    }

    function generateCode() {
        var codigo = "";

        for (let i = 0; i < 4; i++) {
            codigo += generateStr();
        }
        return codigo;
    }

    function getCodes(cant) {
        //635376
        for (var i = 0; i < cant; i++) {
            var code = generateCode();
            while (codigos.includes(code)) {
                code = generateCode();
            }
            codigos.push(code);
        }
        return codigos;
    }

    codigos = getCodes(635376);
    codigos = codigos.sort();

    //getCodes(635376);
    //console.log(getCodes(19999))
    //console.log(codigos.indexOf('aaaa'))
    res.json({
        "codigos": codigos.length,
    })
}

module.exports = {
    pruebaDeyner,
}
