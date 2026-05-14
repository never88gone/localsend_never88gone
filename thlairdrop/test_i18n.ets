import i18n from '@ohos.i18n';
try {
  i18n.System.setAppPreferredLanguage('en-US');
  console.log("Success");
} catch(e) {
  console.log("Error: " + e);
}
