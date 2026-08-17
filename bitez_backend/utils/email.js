const nodemailer = require('nodemailer');

const sendEmail = async (options) => {
  // If no email host is provided in .env, we can generate a test account using ethereal
  let transporter;
  if (!process.env.EMAIL_HOST) {
    console.log("No SMTP settings found in .env, using test account (Ethereal).");
    let testAccount = await nodemailer.createTestAccount();
    transporter = nodemailer.createTransport({
      host: "smtp.ethereal.email",
      port: 587,
      secure: false, // true for 465, false for other ports
      auth: {
        user: testAccount.user, // generated ethereal user
        pass: testAccount.pass, // generated ethereal password
      },
    });
  } else {
    transporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST,
      port: process.env.EMAIL_PORT,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
  }

  const mailOptions = {
    from: 'Bitez Support <support@bitez.app>',
    to: options.email,
    subject: options.subject,
    text: options.message,
    html: options.html, // Optional HTML message
  };

  try {
    let info = await transporter.sendMail(mailOptions);
    console.log(`Email sent to ${options.email}`);
    
    // For ethereal test accounts, print the preview URL
    if (!process.env.EMAIL_HOST) {
      console.log("Preview URL: %s", nodemailer.getTestMessageUrl(info));
    }
  } catch (err) {
    console.error('Error sending email:', err);
    throw new Error('There was an error sending the email. Try again later!');
  }
};

module.exports = sendEmail;
