import {
  createTheme,
  getTheme as getThemeOriginal,
  loadTheme,
} from "@fluentui/react/lib/index.bundle";

export * from "@fluentui/react/lib/index.bundle";

const oxfordTheme = createTheme({
  palette: {
    themePrimary: "#002147",
    themeDark: "#001633",
    themeDarker: "#000d20",
    themeDarkAlt: "#002c63",
    themeLight: "#33527a",
    themeLighter: "#c3cfdf",
    themeLighterAlt: "#f4f6f9",
  },
  semanticColors: {
    link: "#002147",
    linkHovered: "#001633",
    buttonText: "#002147",
    buttonBorder: "#002147",
    buttonTextHovered: "#001633",
  },
});

let loaded = false;
export const getTheme = (...args: Parameters<typeof getThemeOriginal>) => {
  if (!loaded) {
    loadTheme(oxfordTheme);
    loaded = true;
  }
  return getThemeOriginal(...args);
};

