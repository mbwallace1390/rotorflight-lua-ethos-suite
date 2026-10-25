"""Resolve real locale entries in desktop fixtures just as packaging does."""
import importlib.util
from functools import lru_cache
from pathlib import Path
@lru_cache(maxsize=24)
def locale_catalog(source, lang):
    root = Path(source).parents[1]
    path = root / ".vscode/scripts/resolve_i18n_tags.py"
    spec = importlib.util.spec_from_file_location("theme_package_resolver", path)
    resolver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(resolver)
    catalog = resolver.load_translations(Path(source) / "i18n" / (lang + ".json"))
    return resolver, catalog

def resolve_source(text, source, lang="en"):
    resolver, catalog = locale_catalog(str(source), lang)
    return resolver.replace_tags_in_text(text, catalog, {})[0]
