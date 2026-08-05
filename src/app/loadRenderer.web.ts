export async function loadRenderer() {
  const { LoadSkiaWeb } = await import('@shopify/react-native-skia/lib/module/web');
  await LoadSkiaWeb();
}
