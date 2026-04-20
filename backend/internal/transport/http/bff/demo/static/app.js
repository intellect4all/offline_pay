(() => {
  const $ = (id) => document.getElementById(id);
  const acctInput = $("account_number");
  const bankSel = $("bank_code");
  const btnVerify = $("btn-verify");
  const stepLookup = $("step-lookup");
  const stepFund = $("step-fund");
  const holderName = $("holder-name");
  const holderAccount = $("holder-account");
  const amountInput = $("amount");
  const btnFund = $("btn-fund");
  const btnReset = $("btn-reset");
  const banner = $("banner");

  let verified = null;

  const showBanner = (kind, text) => {
    banner.innerHTML = `<div class="banner ${kind}">${text}</div>`;
  };
  const clearBanner = () => { banner.innerHTML = ""; };

  const formatNaira = (kobo) => {
    const naira = kobo / 100;
    return "\u20A6" + naira.toLocaleString("en-NG", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  const setBusy = (btn, busy) => {
    btn.disabled = busy;
    if (busy) btn.dataset.originalLabel = btn.textContent;
    btn.textContent = busy ? "Working…" : btn.dataset.originalLabel || btn.textContent;
  };

  const postJSON = async (url, body) => {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg = data.message || `HTTP ${res.status}`;
      const err = new Error(msg);
      err.code = data.code;
      err.status = res.status;
      throw err;
    }
    return data;
  };

  btnVerify.addEventListener("click", async () => {
    clearBanner();
    const account = acctInput.value.trim();
    if (!/^[0-9]{10}$/.test(account)) {
      showBanner("error", "Account number must be exactly 10 digits.");
      return;
    }
    setBusy(btnVerify, true);
    try {
      const data = await postJSON("/demo/name-enquiry", {
        account_number: account,
        bank_code: bankSel.value,
      });
      verified = { account, name: data.full_name };
      holderName.textContent = data.full_name || "(no name on file)";
      holderAccount.textContent = data.account_number;
      stepLookup.classList.add("hidden");
      stepFund.classList.remove("hidden");
      amountInput.focus();
    } catch (err) {
      showBanner("error", err.message);
    } finally {
      setBusy(btnVerify, false);
    }
  });

  btnFund.addEventListener("click", async () => {
    clearBanner();
    if (!verified) return;
    const naira = Number(amountInput.value);
    if (!Number.isFinite(naira) || naira <= 0) {
      showBanner("error", "Enter an amount in naira greater than zero.");
      return;
    }
    if (naira > 500000) {
      showBanner("error", "Maximum per mint is \u20A6500,000.");
      return;
    }
    const kobo = Math.round(naira * 100);
    if (kobo < 100) {
      showBanner("error", "Minimum per mint is \u20A61.");
      return;
    }
    setBusy(btnFund, true);
    try {
      const data = await postJSON("/demo/fund", {
        account_number: verified.account,
        bank_code: bankSel.value,
        amount_kobo: kobo,
      });
      showBanner(
        "success",
        `Funded ${formatNaira(kobo)} to ${verified.name}. New balance: ${formatNaira(data.new_balance_kobo)}. Txn ${data.txn_id}.`
      );
      amountInput.value = "";
    } catch (err) {
      showBanner("error", err.message);
    } finally {
      setBusy(btnFund, false);
    }
  });

  btnReset.addEventListener("click", () => {
    clearBanner();
    verified = null;
    acctInput.value = "";
    amountInput.value = "";
    stepFund.classList.add("hidden");
    stepLookup.classList.remove("hidden");
    acctInput.focus();
  });

  acctInput.focus();
})();
