export function useKobo() {
  const fmt = new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', minimumFractionDigits: 2 })
  return {
    toNaira: (kobo: number | bigint) => Number(kobo) / 100,
    format: (kobo: number | bigint | null | undefined) => {
      if (kobo == null) return '—'
      return fmt.format(Number(kobo) / 100)
    },
  }
}
