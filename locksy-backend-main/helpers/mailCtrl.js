var nodemailer = require('nodemailer'); 
//https://myaccount.google.com/lesssecureapps
//https://accounts.google.com/b/0/DisplayUnlockCaptcha
exports.sendEmail = function (req, res) {
    var transporter = nodemailer.createTransport({
        service: 'Gmail',
        auth: {
            user: 'info.tollray@gmail.com', 
            pass: 'ANIMINKIS'
        }
    });
    var mailOptions = {
        from: req.body.from,
        to: req.body.to,
        subject: req.body.subject,
        html: req.body.text,
    };
    transporter.sendMail(mailOptions, function (error, info) {
        console.log(info)
        if (error) {
            console.log(error);
            res.send(500, err.message);
        } else {
            console.log("Email enviado..."); 
            res.status(200).jsonp(req.body);
        }
    });
};
