local _, ns = ...
ns.MaxLanguages = 2
ns.LanguagePacks = ns.LanguagePacks or {}
ns.LanguagePacks.enUS = { chunks = ns.DictionaryChunks, blocked = ns.NoSuggestChunks }
ns.DictionaryChunks, ns.NoSuggestChunks = nil, nil
ns.Languages = {
	{ "enUS", "English (US)" }, { "enGB", "English (UK)" },
	{ "deDE", "Deutsch" }, { "frFR", "Français" },
	{ "esES", "Español" }, { "itIT", "Italiano" },
	{ "nlNL", "Nederlands (NL)" }, { "nlBE", "Nederlands (BE)" },
}
ns.LanguagePacks.nlBE = ns.LanguagePacks.nlNL
