/* Settings for this copy of the app. The setup script (setup/setup.sh or setup.ps1) fills in the reminder key;
   nothing else needs changing. Also read by .github/reminders/remind.mjs. */
window.LEDGER_CONFIG = {
  appName: 'Family Finances Tracker',
  brandHtml: 'Family <em>Finances</em> Tracker', // the title in the header; <em> is shown in the accent colour
  // Public half of the phone-reminder key pair. The private half is the VAPID_PRIVATE_KEY repo secret.
  // Blank = phone notifications are switched off (the calendar reminder still works).
  vapidPublicKey: 'BLjRAa5jJNdhKMmomyO8sVOrT9Iy9YjStw82_nPNpfeGYhrAD4zdTN35cIdiN8WcjrE_II0HlgX9iMhyt7ssKOE',
  // Leave blank on GitHub Pages: the app reads the owner and repo from its own address
  // (<owner>.github.io/<repo>/). Only fill these in if you host it somewhere else.
  owner: '',
  repo: '',
};
