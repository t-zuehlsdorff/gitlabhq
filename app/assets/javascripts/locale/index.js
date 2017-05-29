import Jed from 'jed';

/**
  This is required to require all the translation folders in the current directory
  this saves us having to do this manually & keep up to date with new languages
**/
function requireAll(requireContext) { return requireContext.keys().map(requireContext); }

const allLocales = requireAll(require.context('./', true, /^(?!.*(?:index.js$)).*\.js$/));
const locales = allLocales.reduce((d, obj) => {
  const data = d;
  const localeKey = Object.keys(obj)[0];

  data[localeKey] = obj[localeKey];

  return data;
}, {});

let lang = document.querySelector('html').getAttribute('lang') || 'en';
lang = lang.replace(/-/g, '_');

const locale = new Jed(locales[lang]);

/**
  Translates `text`

  @param text The text to be translated
  @returns {String} The translated text
**/
const gettext = locale.gettext.bind(locale);

/**
  Translate the text with a number
  if the number is more than 1 it will use the `pluralText` translation.
  This method allows for contexts, see below re. contexts

  @param text Singular text to translate (eg. '%d day')
  @param pluralText Plural text to translate (eg. '%d days')
  @param count Number to decide which translation to use (eg. 2)
  @returns {String} Translated text with the number replaced (eg. '2 days')
**/
const ngettext = (text, pluralText, count) => {
  const translated = locale.ngettext(text, pluralText, count).replace(/%d/g, count).split('|');

  return translated[translated.length - 1];
};

/**
  Translate context based text
  Either pass in the context translation like `Context|Text to translate`
  or allow for dynamic text by doing passing in the context first & then the text to translate

  @param keyOrContext Can be either the key to translate including the context
                      (eg. 'Context|Text') or just the context for the translation
                      (eg. 'Context')
  @param key Is the dynamic variable you want to be translated
  @returns {String} Translated context based text
**/
const pgettext = (keyOrContext, key) => {
  const normalizedKey = key ? `${keyOrContext}|${key}` : keyOrContext;
  const translated = gettext(normalizedKey).split('|');

  return translated[translated.length - 1];
};

export { lang };
export { gettext as __ };
export { ngettext as n__ };
export { pgettext as s__ };
export default locale;
