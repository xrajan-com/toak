// scripts/main.js

document.addEventListener("DOMContentLoaded", () => {
  const API_URL =
    window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1"
      ? "http://localhost:3000"
      : "https://api.tenofakind.com";

  const auth =
    window.firebase && typeof firebase.auth === "function" ? firebase.auth() : null;

  const _profileKey = (uid) => `tok.profile.${uid}`;
  const readExtraProfile = (uid) => {
    try {
      const raw = localStorage.getItem(_profileKey(uid));
      return raw ? JSON.parse(raw) : {};
    } catch (_) {
      return {};
    }
  };
  const writeExtraProfile = (uid, patch) => {
    const current = readExtraProfile(uid);
    const next = { ...current, ...patch };
    localStorage.setItem(_profileKey(uid), JSON.stringify(next));
    return next;
  };

  const firebaseErrorMessage = (e) => {
    const code = (e && e.code) ? String(e.code) : "";
    switch (code) {
      case "auth/email-already-in-use":
        return "Email already in use.";
      case "auth/invalid-email":
        return "Invalid email address.";
      case "auth/weak-password":
        return "Password is too weak (use 8+ characters).";
      case "auth/user-not-found":
      case "auth/wrong-password":
        return "Invalid email or password.";
      case "auth/too-many-requests":
        return "Too many attempts. Try again later.";
      default:
        return (e && e.message) ? String(e.message) : "Something went wrong.";
    }
  };

  const DOM = {
    viewIdCardBtn: document.getElementById("viewIdCardBtn"),
    idCardDisplay: document.querySelector(".id-card-display"),
    editProfileBtn: document.getElementById("editProfileBtn"),
    editProfileForm: document.getElementById("editProfileForm"),
    loginModal: document.getElementById("loginRegisterModal"),
    profileModal: document.getElementById("profileModal"),
    leaderboardModal: document.getElementById("leaderboardModal"),
    aboutPopup: document.getElementById("aboutPopup"),
    supportPopup: document.getElementById("supportPopup"),
    featurePopup: document.getElementById("featurePopup"),
    featureTitle: document.getElementById("featurePopupTitle"),
    featureText: document.getElementById("featurePopupText"),
    venueModal: document.getElementById("venueDetailModal"),
    venueModalGroup: document.getElementById("venueModalGroup"),
    venueModalTitle: document.getElementById("venueModalTitle"),
    venueModalHistory: document.getElementById("venueModalHistory"),
    venueFortList: document.getElementById("venueFortList")
  };

  const flagByKingdom = {
    "Baroda": "baroda.png",
    "Hyderabad": "hyderabad.png",
    "Indore": "indore.png",
    "Jaipur": "jaipur.png",
    "Maratha Empire": "maratha-empire.png",
    "Mysore": "mysore.png",
    "New Delhi": "new-delhi.png",
    "Sikh Empire": "sikh-empire.png",
    "Sikkim": "sikkim.png",
    "Travancore": "travancore.png",
    "Africa": "africa.png",
    "Amazon": "amazon.png",
    "America": "america.png",
    "Arabia": "arabia.png",
    "Australia": "australia.png",
    "China": "china.png",
    "Europe": "europe.png",
    "India": "india.png",
    "Russia": "russia.png",
    "Southeast": "southeast.png"
  };

  const kingdomFlagSrc = (kingdomName) => {
    const key = (kingdomName || "").trim();
    const file = flagByKingdom[key];
    return file ? `images/venues/${file}` : "Logo.png";
  };

  const toggleModal = (el, show = true) => el.classList[show ? 'add' : 'remove']("active");
  const closeAllModals = () => document.querySelectorAll(".modal-overlay.active").forEach(el => toggleModal(el, false));
  const demoLoader = document.getElementById("demoLoader");

  function switchView(showLogin) {
    document.getElementById("loginForm").style.display = showLogin ? "block" : "none";
    document.getElementById("registerForm").style.display = showLogin ? "none" : "block";
    document.getElementById("modalTitle").innerText = showLogin ? "Login" : "Register";
  }

  const openLoginRegisterModal = () => {
    closeAllModals();
    switchView(true);
    toggleModal(DOM.loginModal, true);
  };

  const openLoginModalBtn = document.getElementById("openLoginModal");
  if (openLoginModalBtn) {
    openLoginModalBtn.addEventListener("click", (e) => {
      e.preventDefault();
      openLoginRegisterModal();
    });
  }

  const profileIconLink = document.querySelector(".profile-icon-link");
  if (profileIconLink) {
    profileIconLink.addEventListener("click", (e) => {
      e.preventDefault();
      closeAllModals();
      const isSignedIn = Boolean(auth && auth.currentUser);
      toggleModal(isSignedIn ? DOM.profileModal : DOM.loginModal, true);
      if (!isSignedIn) switchView(true);
    });
  }

  const leaderboardLink = document.getElementById("leaderboardLink");
  if (leaderboardLink) {
    leaderboardLink.addEventListener("click", (e) => {
      e.preventDefault();
      toggleModal(DOM.leaderboardModal, true);
      populateLeaderboard();
    });
  }

  ["closeModal", "closeProfileModal", "closeLeaderboardModal", "closeFeatureModal", "closeVenueModal"].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("click", closeAllModals);
  });

  document.querySelectorAll(".modal-overlay").forEach(overlay => {
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) closeAllModals();
    });
  });

  document.getElementById("switchToRegister").addEventListener("click", e => { e.preventDefault(); switchView(false); });
  document.getElementById("switchToLogin").addEventListener("click", e => { e.preventDefault(); switchView(true); });

  const popupPairs = [
    { trigger: "aboutLink", target: "aboutPopup" },
    { trigger: "supportLink", target: "supportPopup" },
    { trigger: "aboutLinkVenue", target: "aboutPopupVenue" },
    { trigger: "supportLinkVenue", target: "supportPopupVenue" },
    { trigger: "disclaimerLink", target: "disclaimerPopup" },
    { trigger: "disclaimerLinkVenue", target: "disclaimerPopupVenue" }
  ];

  const popupTimers = new Map();
  const hidePopup = (id) => {
    const el = document.getElementById(id);
    if (el) toggleModal(el, false);
  };
  const scheduleHide = (id) => {
    clearTimeout(popupTimers.get(id));
    const timeoutId = setTimeout(() => hidePopup(id), 2000);
    popupTimers.set(id, timeoutId);
  };
  const cancelHide = (id) => clearTimeout(popupTimers.get(id));

  popupPairs.forEach(({ trigger, target }) => {
    const triggerEl = document.getElementById(trigger);
    const targetEl = document.getElementById(target);
    if (!triggerEl || !targetEl) return;

    triggerEl.addEventListener("click", e => {
      e.preventDefault();
      // hide other popups first
      popupPairs.forEach(p => hidePopup(p.target));
      toggleModal(targetEl, true);
    });

    triggerEl.addEventListener("mouseleave", () => scheduleHide(target));
    triggerEl.addEventListener("mouseenter", () => cancelHide(target));
    targetEl.addEventListener("mouseenter", () => cancelHide(target));
    targetEl.addEventListener("mouseleave", () => scheduleHide(target));
  });

  document.querySelectorAll(".close-popup").forEach(btn => {
    btn.addEventListener("click", () => {
      [DOM.aboutPopup, DOM.supportPopup, document.getElementById("aboutPopupVenue"), document.getElementById("supportPopupVenue"), document.getElementById("disclaimerPopup"), document.getElementById("disclaimerPopupVenue"), DOM.featurePopup].forEach(p => p && toggleModal(p, false));
    });
  });

  const featureInfo = {
    play: { title: "Play as Guest", text: "Train yourself before the big game." },
    career: { title: "Start Your Career", text: "Compete like a true poker king." },
    host: { title: "Host an Event", text: "Host your own table and invite friends." },
    free: { title: "It's Free!", text: "Yes, it’s free — but maybe not forever." },
    rules: { title: "Texas Hold'em Rules", text: "We follow tournament-standard Texas Hold’em rules." }
  };

  const flipFeature = (el) => {
    document.querySelectorAll(".feature").forEach(other => {
      if (other !== el) other.classList.remove("is-flipped");
    });
    el.classList.toggle("is-flipped");
  };

  document.querySelectorAll(".feature").forEach(el => {
    const type = el.dataset.feature;
    const info = featureInfo[type];
    const backTitle = el.querySelector(".feature-back h4");
    const backText = el.querySelector(".feature-back p");
    if (info && backTitle && backText) {
      backTitle.innerText = info.title;
      backText.innerText = info.text;
    }

    el.addEventListener("click", (e) => {
      e.preventDefault();
      flipFeature(el);
    });

    el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        flipFeature(el);
      }
    });
  });

  document.getElementById("closeFeaturePopup").addEventListener("click", () => toggleModal(DOM.featurePopup, false));

  const venueInfo = {
    "Baroda": {
      group: "Royal Indian Circuit",
      history: "Baroda grew under the Gaekwads into one of western India's most reform-minded princely states, known for public works, education, and a confident court culture.",
      forts: [
        {
          name: "Dabhoi Fort",
          about: "Dabhoi's old fortifications preserve carved gates and Solanki-era stonework near Baroda. The town guarded trade routes and still reads like a compact fortified city."
        },
        {
          name: "Champaner-Pavagadh",
          about: "The Champaner-Pavagadh complex layers hill forts, mosques, stepwells, and royal remains across a volcanic ridge. It became a UNESCO site for its rare, largely unchanged pre-Mughal urban fabric."
        },
        {
          name: "Baroda Walled City Gates",
          about: "Mandvi and the old city gates mark Baroda's fortified urban core. They recall a capital built around trade, administration, and ceremonial movement through the city."
        }
      ]
    },
    "Hyderabad": {
      group: "Royal Indian Circuit",
      history: "Hyderabad was the seat of the Qutb Shahi rulers and later the Asaf Jahi nizams, joining Persianate court style with Deccan military power and a wealthy trading culture.",
      forts: [
        {
          name: "Golconda Fort",
          about: "Golconda controlled the diamond-rich Deccan and became famous for its acoustic defenses, gateways, and layered walls. Its ruins still show how palace life and military design were fused."
        },
        {
          name: "Warangal Fort",
          about: "Warangal was a Kakatiya stronghold before later Deccan powers fought over it. Its carved gateways and stone remains point to a powerful medieval Telugu capital."
        },
        {
          name: "Medak Fort",
          about: "Medak Fort sits on a hill that watched the northern approaches to Hyderabad. Kakatiya, Bahmani, and Qutb Shahi phases are visible in its walls, granaries, and bastions."
        }
      ]
    },
    "Indore": {
      group: "Royal Indian Circuit",
      history: "Indore rose with the Holkars, a Maratha house that turned a trading town into a central Indian power base while patronizing temples, markets, and river cities.",
      forts: [
        {
          name: "Ahilya Fort, Maheshwar",
          about: "Ahilya Fort overlooks the Narmada and is closely tied to Ahilyabai Holkar's enlightened rule. The fort-palace complex became a center of administration, devotion, and textile patronage."
        },
        {
          name: "Mandu Fort",
          about: "Mandu's plateau walls enclose palaces, reservoirs, and Afghan-era monuments. Its dramatic setting made it one of central India's most memorable fortified capitals."
        },
        {
          name: "Asirgarh Fort",
          about: "Asirgarh was called the key to the Deccan because armies moving south had to reckon with it. Mughals, Marathas, and later British forces all understood its strategic value."
        }
      ]
    },
    "Jaipur": {
      group: "Royal Indian Circuit",
      history: "Jaipur was planned by Sawai Jai Singh II as a scientific, commercial, and royal capital, with Amber's older hill power feeding into the Pink City's urban design.",
      forts: [
        {
          name: "Amber Fort",
          about: "Amber Fort blends Rajput defense with mirrored halls, courtyards, and water systems. It was the Kachwaha seat before Jaipur became the planned capital."
        },
        {
          name: "Jaigarh Fort",
          about: "Jaigarh watched over Amber and housed artillery, armories, and treasury routes. Its long walls and cannon works made it a military backbone for the Jaipur rulers."
        },
        {
          name: "Nahargarh Fort",
          about: "Nahargarh crowns the Aravalli ridge above Jaipur. Built as a defensive retreat, it later became a scenic royal residence overlooking the city grid."
        }
      ]
    },
    "Maratha Empire": {
      group: "Royal Indian Circuit",
      history: "The Maratha Empire grew from hill forts, mobile cavalry, and local revenue networks into a major early modern Indian power that challenged Mughal authority.",
      forts: [
        {
          name: "Raigad Fort",
          about: "Raigad was Chhatrapati Shivaji Maharaj's coronation capital. Its cliff defenses, gateways, and royal precinct made it a symbol of Maratha statehood."
        },
        {
          name: "Sinhagad Fort",
          about: "Sinhagad guarded the Pune region and is remembered for fierce Maratha campaigns. The fort's steep approaches explain why it was so hard to storm."
        },
        {
          name: "Sindhudurg Fort",
          about: "Sindhudurg was built in the Arabian Sea to strengthen Maratha naval power. Its sea walls and hidden entrances show a coastal strategy beyond hill warfare."
        }
      ]
    },
    "Mysore": {
      group: "Royal Indian Circuit",
      history: "Mysore moved between Wodeyar kingship and the military reforms of Haidar Ali and Tipu Sultan, becoming a southern power known for rockets, diplomacy, and palace culture.",
      forts: [
        {
          name: "Srirangapatna Fort",
          about: "Srirangapatna was Tipu Sultan's island capital and a key battlefield in the Anglo-Mysore Wars. Its walls, gates, and dungeons carry the story of Mysore's resistance."
        },
        {
          name: "Chitradurga Fort",
          about: "Chitradurga's seven rings of walls climb through granite hills. It protected central Karnataka and shows how terrain itself became part of the defense."
        },
        {
          name: "Bangalore Fort",
          about: "Bangalore Fort began as a mud fort and later became a stone stronghold under Haidar Ali. British capture of the fort marked a turning point in the Third Anglo-Mysore War."
        }
      ]
    },
    "New Delhi": {
      group: "Royal Indian Circuit",
      history: "Delhi's region has hosted many capitals, from Sultanate cities to Mughal Shahjahanabad and modern New Delhi, leaving a dense record of power changing hands.",
      forts: [
        {
          name: "Red Fort",
          about: "The Red Fort was Shah Jahan's imperial citadel and became a symbol of Mughal authority. Its halls, gardens, and walls later gained national importance in modern India."
        },
        {
          name: "Purana Qila",
          about: "Purana Qila stands on one of Delhi's old settlement mounds. Afghan and Mughal builders shaped the surviving walls, gateways, and mosque."
        },
        {
          name: "Tughlaqabad Fort",
          about: "Tughlaqabad was built as a massive 14th-century fortified city. Its broken ramparts still show the hard, austere style of the Tughlaq dynasty."
        }
      ]
    },
    "Sikh Empire": {
      group: "Royal Indian Circuit",
      history: "The Sikh Empire under Maharaja Ranjit Singh unified Punjab and surrounding regions through disciplined armies, diplomacy, and control of key frontier forts.",
      forts: [
        {
          name: "Lahore Fort",
          about: "Lahore Fort became a major Sikh imperial seat after earlier Mughal glory. Ranjit Singh's court adapted its palaces, gates, and ceremonial spaces."
        },
        {
          name: "Gobindgarh Fort",
          about: "Gobindgarh guarded Amritsar and held the famed Toshakhana treasury. The fort reflects the military and symbolic priorities of Sikh rule."
        },
        {
          name: "Kangra Fort",
          about: "Kangra Fort is one of the Himalaya's great strongholds. Its control mattered to hill states, Mughals, Sikhs, and later the British."
        }
      ]
    },
    "Sikkim": {
      group: "Royal Indian Circuit",
      history: "Sikkim's Namgyal kingdom sat between Himalayan trade routes and powerful neighbors, with monasteries and hill settlements shaping its political identity.",
      forts: [
        {
          name: "Rabdentse Ruins",
          about: "Rabdentse was Sikkim's second capital and now survives as palace and wall remains near Pelling. The ruins show a Himalayan court positioned for defense and ritual authority."
        },
        {
          name: "Tumlong",
          about: "Tumlong served as a later Sikkimese capital before Gangtok. Its remains point to shifting royal centers as politics and terrain changed."
        },
        {
          name: "Damsang Fort",
          about: "Damsang Fort near Kalimpong is linked with Lepcha and Bhutanese frontier history. It represents the fortified edges of the eastern Himalayan world."
        }
      ]
    },
    "Travancore": {
      group: "Royal Indian Circuit",
      history: "Travancore became a strong southern kingdom through maritime trade, temple wealth, military reform, and careful diplomacy along the Kerala coast.",
      forts: [
        {
          name: "Udayagiri Fort",
          about: "Udayagiri Fort was rebuilt under Marthanda Varma and later associated with European military expertise. Its walls and foundry supported Travancore's modernizing army."
        },
        {
          name: "Vattakottai Fort",
          about: "Vattakottai is a seaside fort near Kanyakumari with views of the Western Ghats and the coast. It guarded the southern edge of Travancore's territory."
        },
        {
          name: "Anchuthengu Fort",
          about: "Anchuthengu Fort was an English East India Company post on the Kerala coast. It reflects the maritime pressures Travancore had to balance."
        }
      ]
    },
    "Africa": {
      group: "International Circuit",
      history: "The Africa circuit points to a continent of ancient kingdoms, coastal trade forts, inland stone cities, and colonial-era strongholds that shaped global exchange.",
      forts: [
        {
          name: "Great Zimbabwe",
          about: "Great Zimbabwe was a stone-built medieval capital tied to gold trade and regional power. Its massive dry-stone walls remain among Africa's great archaeological landmarks."
        },
        {
          name: "Fort Jesus",
          about: "Fort Jesus in Mombasa was built by the Portuguese to control Indian Ocean trade. Its later history passed through Omani, local, and British hands."
        },
        {
          name: "Elmina Castle",
          about: "Elmina Castle began as a Portuguese trading post on the Gold Coast. Its history is also tied to the Atlantic slave trade, making it a solemn site of memory."
        }
      ]
    },
    "Amazon": {
      group: "International Circuit",
      history: "The Amazon venue follows river empires, forest trade, and frontier forts built to control navigation, borders, and extraction across a vast basin.",
      forts: [
        {
          name: "Forte do Presepio",
          about: "Forte do Presepio anchored the Portuguese founding of Belem at the mouth of the Amazon. It guarded river access and the early colonial settlement."
        },
        {
          name: "Fort Principe da Beira",
          about: "Fort Principe da Beira was built deep inland to mark Portuguese claims near the Guapore River. Its remote walls speak to border rivalry in the rainforest."
        },
        {
          name: "Fortaleza de Sao Jose de Macapa",
          about: "Macapa's fortress protected the northern Amazon and Atlantic approaches. Its star-shaped plan reflects 18th-century military engineering."
        }
      ]
    },
    "America": {
      group: "International Circuit",
      history: "America's fort story spans Indigenous homelands, Spanish coastal defense, colonial wars, revolution, and civil conflict across a continent of contested frontiers.",
      forts: [
        {
          name: "Castillo de San Marcos",
          about: "This St. Augustine fortress is the oldest masonry fort in the continental United States. Its coquina walls withstood sieges that would have shattered harder stone."
        },
        {
          name: "Fort Ticonderoga",
          about: "Fort Ticonderoga controlled the route between Lake George and Lake Champlain. It changed hands during imperial wars and the American Revolution."
        },
        {
          name: "Fort Sumter",
          about: "Fort Sumter in Charleston Harbor became the opening flashpoint of the American Civil War. Its brick walls became a national symbol of division and reunion."
        }
      ]
    },
    "Arabia": {
      group: "International Circuit",
      history: "Arabia's circuit moves through oasis towns, caravan routes, coastal ports, and desert fortresses that protected trade, dynasties, and tribal alliances.",
      forts: [
        {
          name: "Masmak Fort",
          about: "Masmak Fort in Riyadh is tied to the 1902 recapture that helped launch modern Saudi rule. Its mud-brick towers show Najdi defensive architecture."
        },
        {
          name: "Nizwa Fort",
          about: "Nizwa Fort guarded one of Oman's historic inland capitals. Its huge round tower was designed to dominate the oasis and surrounding approaches."
        },
        {
          name: "Al Jahili Fort",
          about: "Al Jahili Fort in Al Ain protected palm groves and local authority in the oasis. It later became associated with travel, patrols, and desert governance."
        }
      ]
    },
    "Australia": {
      group: "International Circuit",
      history: "Australia's fortifications were shaped by coastal defense, colonial ports, and fears of naval attack, especially around harbors and strategic headlands.",
      forts: [
        {
          name: "Fort Denison",
          about: "Fort Denison sits inside Sydney Harbour and was built as a colonial defensive battery. Its island profile became a familiar part of the harbor landscape."
        },
        {
          name: "Fort Queenscliff",
          about: "Fort Queenscliff protected the entrance to Port Phillip Bay. It formed part of one of Australia's most important coastal defense networks."
        },
        {
          name: "Fort Scratchley",
          about: "Fort Scratchley guarded Newcastle and famously fired on a Japanese submarine in 1942. The site connects colonial defenses with World War II history."
        }
      ]
    },
    "China": {
      group: "International Circuit",
      history: "China's circuit draws from imperial walls, frontier passes, river forts, and port defenses built across centuries of dynastic statecraft and foreign pressure.",
      forts: [
        {
          name: "Jiayuguan Fort",
          about: "Jiayuguan marked the western end of the Ming Great Wall. It controlled Silk Road movement between the Chinese heartland and Central Asia."
        },
        {
          name: "Xi'an City Wall",
          about: "Xi'an's city wall is one of China's best-preserved urban fortifications. It enclosed a former imperial capital with gates, towers, and a broad defensive circuit."
        },
        {
          name: "Humen Forts",
          about: "The Humen Forts defended the Pearl River approach to Guangzhou. They became important during the Opium War, when coastal defense met modern naval power."
        }
      ]
    },
    "Europe": {
      group: "International Circuit",
      history: "Europe's venue spans castles, walled cities, citadels, and border forts built through feudal rivalries, imperial wars, and urban republics.",
      forts: [
        {
          name: "Tower of London",
          about: "The Tower of London began as a Norman fortress and became a royal palace, prison, mint, and armory. Its layered uses mirror English state power."
        },
        {
          name: "Carcassonne",
          about: "Carcassonne's double walls and towers preserve a medieval fortified city in southern France. It shows how urban life and military architecture overlapped."
        },
        {
          name: "Edinburgh Castle",
          about: "Edinburgh Castle sits on a volcanic rock above Scotland's capital. It guarded royal authority and saw repeated sieges during wars over the Scottish crown."
        }
      ]
    },
    "India": {
      group: "International Circuit",
      history: "The global India venue represents the subcontinent's layered fort traditions, from Rajput hill citadels to Mughal imperial seats and Deccan strongholds.",
      forts: [
        {
          name: "Red Fort",
          about: "Delhi's Red Fort was the ceremonial heart of the Mughal Empire. It later became a national stage for independence-era memory and annual addresses."
        },
        {
          name: "Gwalior Fort",
          about: "Gwalior Fort dominates a sandstone plateau and controlled central Indian routes. Rajput, Mughal, Maratha, and British periods all left marks there."
        },
        {
          name: "Chittorgarh Fort",
          about: "Chittorgarh is one of India's largest hill forts and a symbol of Mewar resistance. Its palaces, towers, and reservoirs tell a long Rajput story."
        }
      ]
    },
    "Russia": {
      group: "International Circuit",
      history: "Russia's fort history runs from kremlins and river citadels to Baltic and Pacific defenses, reflecting a state built across immense distances.",
      forts: [
        {
          name: "Moscow Kremlin",
          about: "The Moscow Kremlin is a fortified political and religious center at the heart of Russia. Its walls and towers frame centuries of princely, imperial, Soviet, and modern power."
        },
        {
          name: "Peter and Paul Fortress",
          about: "Peter and Paul Fortress founded St. Petersburg as a Baltic stronghold. It later became a prison and a ceremonial landmark of the imperial capital."
        },
        {
          name: "Vladivostok Fortress",
          about: "Vladivostok Fortress defended Russia's Pacific port with batteries, tunnels, and hill positions. It shows the scale of late imperial military engineering."
        }
      ]
    },
    "Southeast": {
      group: "International Circuit",
      history: "The Southeast circuit follows monsoon trade, island ports, temple cities, and colonial bastions across a region shaped by sea lanes and inland kingdoms.",
      forts: [
        {
          name: "Fort Santiago",
          about: "Fort Santiago guarded Manila's Intramuros district under Spanish rule. Its history includes trade, war, imprisonment, and Philippine national memory."
        },
        {
          name: "Fort Cornwallis",
          about: "Fort Cornwallis in Penang was built by the British East India Company. It protected a strategic port on the Strait of Malacca."
        },
        {
          name: "Hue Imperial City",
          about: "Hue's citadel enclosed the Nguyen dynasty's imperial capital. Its walls, gates, and palaces became central to Vietnam's royal and wartime history."
        }
      ]
    }
  };

  const subVenueNames = {
    "Baroda": [
      "Bhadra Fort",
      "Bhujia Fort",
      "Dhoraji Fort",
      "Diu Fort",
      "Lakhota Fort",
      "Pavagadh Fort",
      "Surat Fort",
      "Uparkot Fort"
    ],
    "Jaipur": [
      "Achalgarh Fort",
      "Chittorgarh Fort",
      "Jalore Fort",
      "Junagarh Fort",
      "Kumbhalgarh Fort",
      "Lohagarh Fort",
      "Mehrangarh Fort",
      "Sajjangarh Fort",
      "Taragarh Fort"
    ],
    "Hyderabad": [
      "Bhongir Fort",
      "Golconda Fort",
      "Konda Reddy Fort",
      "Kondapalli Fort",
      "Warangal Fort"
    ],
    "Mysore": [
      "Bangalore Fort",
      "Chitradurga Fort",
      "Madikeri Fort",
      "Manjarabad Fort",
      "Srirangapatna Fort"
    ],
    "Travancore": [
      "Dindigul Fort",
      "East Fort",
      "Pallippuram Fort",
      "Tiruchirappalli Rock Fort",
      "Udayagiri Fort",
      "Vattakottai Fort"
    ],
    "Indore": [
      "Asirgarh Fort",
      "Dhar Fort",
      "Gwalior Fort",
      "Mandu Fort",
      "Narwar Fort"
    ],
    "New Delhi": [
      "Adilabad Fort",
      "Agra Fort",
      "Allahabad Fort",
      "Ballabhgarh Fort",
      "Chunar Fort",
      "Firoz Shah Kotla",
      "Panipat Fort",
      "Purana Qila",
      "Ramnagar Fort",
      "Red Fort",
      "Salimgarh Fort",
      "Tughlaqabad Fort"
    ],
    "Maratha Empire": [
      "Arnala Fort",
      "Lohagad Fort",
      "Pratapgad Fort",
      "Raigad Fort",
      "Shivneri Fort",
      "Sindhudurg Fort",
      "Sinhagad Fort",
      "Vijaydurg Fort"
    ],
    "Sikh Empire": [
      "Attock Fort",
      "Bahadurgarh Fort",
      "Bahu Fort",
      "Bathinda Fort",
      "Govindgarh Fort",
      "Hari Parbat Fort",
      "Jamrud Fort",
      "Kangra Fort",
      "Keshgarh Fort",
      "Lahore Fort",
      "Lodhi Fort",
      "Manauli Fort",
      "Multan Fort",
      "Nabha Fort",
      "Nandana Fort",
      "Payal Fort",
      "Pharwala Fort",
      "Phillaur Fort",
      "Qila Mubarak Patiala",
      "Rohtas Fort",
      "Sangni Fort",
      "Shahpurkandi Fort",
      "Sheikhupura Fort",
      "Sialkot Fort"
    ],
    "Sikkim": [
      "Barabati Fort",
      "Bihu Loukon Fort",
      "Budang Gadi Fort",
      "Buxa Fort",
      "Damsang Fort",
      "Garh Doul",
      "Ita Fort",
      "Kangla Fort",
      "Rabdentse",
      "Sisupalgarh"
    ],
    "Africa": [
      "Bastion de la Sqala",
      "Cairo Citadel",
      "Castle of Good Hope",
      "Fort d'Estrees",
      "Fort Dauphin",
      "Fort Jesus",
      "Old Fort Durban"
    ],
    "S. America": [
      "Castillo del Morro",
      "Fort Bueras",
      "Fort Charles",
      "Fort Copacabana",
      "Fort of Buenos Aires",
      "Fort San Lorenzo",
      "Itaipu Fortress",
      "San Juan de Ulua"
    ],
    "N. America": [
      "Fort Charlotte",
      "Fort Dallas",
      "Fort Dearborn",
      "Fort Independence",
      "Fort McNair",
      "Fort Moore",
      "Fort Point",
      "Fort Travis",
      "Fort Wadsworth",
      "Fort William H. Seward",
      "Fort York",
      "Old Las Vegas Fort",
      "Saint Ann's Fort"
    ],
    "Arabia": [
      "Al Jalali Fort",
      "Al Koot Fort",
      "Apollonia Fortress",
      "Asfan Castle",
      "Bahrain Fort",
      "Citadel of Damascus",
      "Kuwait Red Fort",
      "Masmak Fort",
      "Qasr Al Hosn",
      "Sidon Sea Castle"
    ],
    "Australia": [
      "Bare Island Fort",
      "Fort Nepean",
      "Fort Queenscliff",
      "Fort Takapuna",
      "Princess Royal Fortress",
      "Tavuni Hill Fort"
    ],
    "China": [
      "Dapeng Fortress",
      "Guia Fortress",
      "Juyong Pass Fortress",
      "Tung Chung Fort",
      "Weiyuan Fort",
      "Wusong Fortress",
      "Xi'an Fortifications"
    ],
    "Europe": [
      "Acropolis Citadel",
      "Akershus Fortress",
      "Bellinzona Castles",
      "Burghausen Castle",
      "Castel Sant'Angelo",
      "Chateau de Vincennes",
      "Fort Pampus",
      "Hohensalzburg Fortress",
      "Kyiv Fortress",
      "Lovrijenac Fortress",
      "Manzanares Castle",
      "Montjuic Castle",
      "Munot Fortress",
      "Poenari Citadel",
      "Sforza Castle",
      "Spandau Citadel",
      "Suomenlinna Fortress",
      "Tower of London",
      "Vysehrad Fortress",
      "Warsaw Citadel"
    ],
    "India": [
      "Agra Fort",
      "Bala Hissar",
      "Bangalore Fort",
      "Castella de Aguada",
      "Chunar Fort",
      "Fort Adelaide",
      "Fort Emmanuel",
      "Fort St. George",
      "Fort William",
      "Gobindgarh Fort",
      "Itakhuli Fort",
      "Kumbhalgarh Fort",
      "Lalbagh Fort",
      "Manora Fort",
      "Miri Fort",
      "Navratangarh Fort",
      "Pavagadh Fort",
      "Raisen Fort",
      "Rohtasgarh Fort",
      "Simtokha Dzong",
      "Sindhuli Gadhi",
      "Vizianagaram Fort"
    ],
    "Russia": [
      "Godlik Fortress",
      "Izborsk Fortress",
      "Moscow Kremlin",
      "Peter and Paul Fortress",
      "Smolensk Fortress",
      "Vladivostok Fortress"
    ],
    "Asia": [
      "Edo Castle",
      "Fort Canning",
      "Fort Cornwallis",
      "Fort Fredrick",
      "Fort Rotterdam",
      "Fort Santiago",
      "Fort Santo Domingo",
      "Gia Dinh Citadel",
      "Imperial Citadel of Thang Long",
      "Longvek Citadel",
      "Nijo Castle",
      "Phra Sumen Fort",
      "Rawat Fort",
      "Rumelihisari"
    ],
    "Amazon": [
      "Castillo del Morro",
      "Fort Bueras",
      "Fort Charles",
      "Fort Copacabana",
      "Fort of Buenos Aires",
      "Fort San Lorenzo",
      "Itaipu Fortress",
      "San Juan de Ulua"
    ],
    "America": [
      "Fort Charlotte",
      "Fort Dallas",
      "Fort Dearborn",
      "Fort Independence",
      "Fort McNair",
      "Fort Moore",
      "Fort Point",
      "Fort Travis",
      "Fort Wadsworth",
      "Fort William H. Seward",
      "Fort York",
      "Old Las Vegas Fort",
      "Saint Ann's Fort"
    ],
    "Southeast": [
      "Edo Castle",
      "Fort Canning",
      "Fort Cornwallis",
      "Fort Fredrick",
      "Fort Rotterdam",
      "Fort Santiago",
      "Fort Santo Domingo",
      "Gia Dinh Citadel",
      "Imperial Citadel of Thang Long",
      "Longvek Citadel",
      "Nijo Castle",
      "Phra Sumen Fort",
      "Rawat Fort",
      "Rumelihisari"
    ]
  };

  const subVenueThemes = {
    "Baroda": [
      "Gujarati grit, sharp value",
      "Garba nights, snap 3-bets",
      "Diamond hands, no punts",
      "Coastal breeze, cold reads",
      "Bazaari swagger, big pots",
      "Dandiya beats, mean bluffs",
      "Temple calm, river bite",
      "Spice heat, steady pressure",
      "Sea-raid stacks, rejam",
      "Quiet smile, loud overbets",
      "Rail jokes, ruthless value",
      "Gujju reads, roast mode"
    ],
    "Jaipur": [
      "Pink-city bluffs, big pots",
      "Desert reads, dagger jams",
      "Amber vibes, royal value",
      "Rajput pride, no mercy",
      "Sandstorm bluffs incoming",
      "Fort walls, fearless raises",
      "Camel tilt? never heard",
      "Gold bazaar, cold 3-bets",
      "Palace calm, savage river",
      "Rajasthan rail, roast you",
      "Sunset stacks, sharp squeezes",
      "Thar heat, mean barrels",
      "Royal grin, ruthless value"
    ],
    "Hyderabad": [
      "Pearl city pressure cooker",
      "Biryani bluffs, spicy jams",
      "Charminar stare, snap 3-bet",
      "Nizam nerves, cold value",
      "Deccan heat, no brakes",
      "Golconda gold, grind mode",
      "Sultan swagger, shove first",
      "Techie math, brutal lines",
      "Pearls out, claws out",
      "Smile off, pressure on"
    ],
    "Mysore": [
      "Tiger stride, river bite",
      "Palace calm, savage value",
      "Rocket bluffs, boom pots",
      "Coffee reads, cold folds",
      "Silk court, savage shove",
      "Wodeyar swagger, no punts",
      "Royal court, ruthless river",
      "Quiet grin, sharp check-raise",
      "Crown on, pressure on",
      "Patience now, pain later"
    ],
    "Travancore": [
      "Backwater bluffs, easy",
      "Coconut calm, sharp claws",
      "Sea breeze, ruthless river",
      "Temple bells, turn barrels",
      "Spice routes, stack routes",
      "Harbour hustle, hero calls",
      "Southside swagger, no punts",
      "Quiet waves, loud overbets",
      "Palm shade, pressure made",
      "Monsoon mood, mean value"
    ],
    "Indore": [
      "Street-food swagger, shove",
      "Poha polite, river savage",
      "Rajwada grind, clean KO",
      "Malwa mood, mean bluffs",
      "Night markets, nasty squeezes",
      "Quiet laugh, sharp raise",
      "No mercy, only value",
      "Spicy stacks, steady hands",
      "Turn pressure, trophy vibes",
      "Cool face, cruel river"
    ],
    "New Delhi": [
      "Metro timing, savage value",
      "Ring-road rage, rejam",
      "Capital grind, no leaks",
      "Capital bluffs, big pots",
      "Old walls, new overbets",
      "Paperwork? I prefer pots",
      "Courtroom calm, river rage",
      "Deadline pressure, snap 3-bets",
      "Bureaucracy? shove anyway",
      "Street food, street fights",
      "Night lights, mean value",
      "Yamuna chill, river kill",
      "Stare down, stack up",
      "Hero calls, zero fear",
      "Mean reads, clean wins",
      "Only pressure, no pity"
    ],
    "Maratha Empire": [
      "Fort raids, fat stacks",
      "Shivaji swagger, snap KO",
      "Peshwa pressure, no punts",
      "Deccan drums, deep runs",
      "Konkan coast, cold value",
      "Cavalry calm, river cut",
      "Steel nerves, spicy overbets",
      "Quick blade, quick rejam",
      "War cry, value high",
      "Crown on, chaos on",
      "Sunset bluffs, sunset value",
      "Edge forged, chips seized"
    ],
    "Sikh Empire": [
      "Punjab lions, big pots",
      "Khalsa calm, brutal jams",
      "Ranjit roar, no mercy",
      "Nihang mode: all in",
      "Khyber gate, cold squeeze",
      "Dhol beats, tilt deletes",
      "Steel kirpan, river cut",
      "Frontier grit, no punts",
      "Lionheart laughs, sharp value",
      "Honor high, bluff higher",
      "No fear, only pressure",
      "Quick rejam, quicker grin",
      "Royal guard, river hard",
      "Mean stare, clean lines",
      "Hard folds, harder barrels",
      "Valor on, overbet on"
    ],
    "Sikkim": [
      "Mountain zen, mean jams",
      "Snowline calm, savage value",
      "Tea trails, tight folds",
      "Monastery mind, no punts",
      "Ridge reads, river knives",
      "Cloud cover, bluff cover",
      "Thin air, thick stacks",
      "Quiet peaks, loud overbets",
      "Himalayan chill, sharp kill",
      "Calm face, cruel river",
      "Summit swagger, snap call",
      "Trail tough, tilt-proof"
    ],
    "Africa": [
      "Savanna swagger, big swings",
      "Sun heat, cold folds",
      "Lion calm, brutal value",
      "Desert grit, sharp squeezes",
      "Coast breeze, chaos barrels",
      "Ancient kings, modern bluffs",
      "Safari eyes, river knives",
      "Tribal beat, tilt defeat",
      "Dust storms, stack storms",
      "Fearless, fresh overbets",
      "Quiet grin, big pots",
      "Pounce fast, punish faster"
    ],
    "S. America": [
      "Jungle bluffs, river knives",
      "Samba tempo, savage value",
      "Volcano cool, brutal jams",
      "Carnival laughs, cruel lines",
      "Rainforest reads, mean bluffs",
      "Riverboat vibes, rejam",
      "Sunset heat, sharp squeezes",
      "Spice & steel, stack steals",
      "Chaos barrels, clean KOs",
      "Loud rail, lethal river",
      "Wild cards, wilder bets",
      "Tango tilt? never heard"
    ],
    "N. America": [
      "Vegas math, brutal value",
      "Big city, bigger bluffs",
      "Cold coffee, colder 3-bets",
      "Roadtrip grit, rejam",
      "Fast lanes, fearless raises",
      "Showtime bluffs, clean wins",
      "Surf calm, savage river",
      "Grind mode, no mercy",
      "Poker face, punchy bets",
      "Hero calls, meme laughs",
      "No punts, only pressure",
      "Chips up, ego down",
      "Loud crowd, cold folds",
      "All gas, no brakes",
      "Stack snatcher, no sorry",
      "Stacks rise, ego falls"
    ],
    "Arabia": [
      "Dune winds, sharp squeezes",
      "Spice souk, savage value",
      "Falcon eyes, claws out",
      "Caravan calm, river rage",
      "Golden sands, cold reads",
      "Desert heat, mean barrels",
      "Mint tea, murder bluffs",
      "Oasis chill, knife river",
      "Sand cold, stacks colder",
      "Silk routes, stack routes",
      "Crescent moon, cruel jams",
      "Sunrise bluffs, sunset value"
    ],
    "Australia": [
      "Outback laughs, overbets",
      "Ocean chill, savage river",
      "Sunburnt bluffs, big pots",
      "No worries, no punts",
      "Wildlife stare, snap shove",
      "Larrikin grin, mean value",
      "Coral coast, cold squeezes",
      "Desert heat, clean KOs",
      "Boomerang bluffs return",
      "No worries, brutal value"
    ],
    "China": [
      "Dragon discipline, river doom",
      "Silk smooth, sudden shove",
      "Great Wall, greater value",
      "Tea calm, brutal jams",
      "Red lanterns, cold reads",
      "Jade guard, sharp squeezes",
      "Fireworks on the turn",
      "Ancient pride, modern grind",
      "No smile, only value",
      "Quiet court, loud overbets",
      "Emperor mode, no punts",
      "Fortune favors the fearless"
    ],
    "Europe": [
      "Solver chic, no punts",
      "Castle calm, cruel value",
      "Espresso reads, snap 3-bets",
      "Musketeer bluffs, clean wins",
      "Knight code, savage river",
      "High fashion, higher bets",
      "Bank-grade value, no leaks",
      "Cold rain, colder folds",
      "Ancient streets, modern grind",
      "Opera calm, dagger jams",
      "Euro swagger, sharp squeezes",
      "Royal roads, ruthless value",
      "Legends only, no mercy",
      "Tight suits, tighter ranges",
      "No drama, only chips",
      "Math clean, ego gone"
    ],
    "India": [
      "Spice roads, stack roads",
      "Masala mood, sharp bluffs",
      "Bollywood bluffs, big pots",
      "Chai breaks, cold 3-bets",
      "Street eats, savage beats",
      "High peaks, higher pots",
      "Coastal breeze, cruel value",
      "Metro timing, no leaks",
      "Fort vibes, fearless jams",
      "Rail laughs, ruthless value",
      "Desi swagger, clean lines",
      "Underdog energy, big wins",
      "Spice up, stack up",
      "Zero punts, full pressure",
      "Hero calls, legend tales",
      "Desi edge, legend vibes"
    ],
    "Russia": [
      "Winter nerves, brutal jams",
      "Ice veins, cold overbets",
      "Red Army pressure, no punts",
      "Siberian stare, snap shove",
      "Vodka jokes, iron folds",
      "Frozen river, sharp knives",
      "Steel rails, savage value",
      "Tsar mode, no mercy",
      "Blizzard bluffs incoming",
      "Cold hands, hot stacks",
      "Iron curtain, clean lines",
      "Cold edge, colder stare"
    ],
    "Asia": [
      "Monsoon bluffs, ninja steals",
      "Island vibes, savage value",
      "Spice fleet, sharp squeezes",
      "Temple calm, dagger jams",
      "Samurai calm, brutal jams",
      "Tiger grin, mean barrels",
      "Jade guard, no leaks",
      "Night market, nasty CR",
      "Sea lanes, stack raids",
      "Quiet zen, loud overbets",
      "Fast trains, faster 3-bets",
      "Lanterns lit, bluffs hit",
      "Road to glory, no punts",
      "Throne vibes, river knives",
      "Legend tales, chip trails",
      "Zen calm, savage edge"
    ],
    "Amazon": [
      "Jungle bluffs, river knives",
      "Samba tempo, savage value",
      "Volcano cool, brutal jams",
      "Carnival laughs, cruel lines",
      "Rainforest reads, mean bluffs",
      "Riverboat vibes, rejam",
      "Sunset heat, sharp squeezes",
      "Spice & steel, stack steals",
      "Chaos barrels, clean KOs",
      "Loud rail, lethal river",
      "Wild cards, wilder bets",
      "Tango tilt? never heard"
    ],
    "America": [
      "Vegas math, brutal value",
      "Big city, bigger bluffs",
      "Cold coffee, colder 3-bets",
      "Roadtrip grit, rejam",
      "Fast lanes, fearless raises",
      "Showtime bluffs, clean wins",
      "Surf calm, savage river",
      "Grind mode, no mercy",
      "Poker face, punchy bets",
      "Hero calls, meme laughs",
      "No punts, only pressure",
      "Chips up, ego down",
      "Loud crowd, cold folds",
      "All gas, no brakes",
      "Stack snatcher, no sorry",
      "Stacks rise, ego falls"
    ],
    "Southeast": [
      "Monsoon bluffs, ninja steals",
      "Island vibes, savage value",
      "Spice fleet, sharp squeezes",
      "Temple calm, dagger jams",
      "Samurai calm, brutal jams",
      "Tiger grin, mean barrels",
      "Jade guard, no leaks",
      "Night market, nasty CR",
      "Sea lanes, stack raids",
      "Quiet zen, loud overbets",
      "Fast trains, faster 3-bets",
      "Lanterns lit, bluffs hit",
      "Road to glory, no punts",
      "Throne vibes, river knives",
      "Legend tales, chip trails",
      "Zen calm, savage edge"
    ]
  };

  const fallbackSubVenueThemes = [
    "All-in energy",
    "Value town vibes",
    "Bluff city",
    "No punts allowed",
    "River knives",
    "Cold 3-bets",
    "Stack raids",
    "Clean lines, mean wins"
  ];

  const fnv1a32 = (value) => {
    let hash = 0x811c9dc5;
    for (let i = 0; i < value.length; i += 1) {
      hash ^= value.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    return hash >>> 0;
  };

  const subVenueAbout = (kingdomName, subVenueName) => {
    const themes = subVenueThemes[kingdomName] || fallbackSubVenueThemes;
    const list = themes.length ? themes : fallbackSubVenueThemes;
    const seed = fnv1a32(`${kingdomName}|${subVenueName}`);
    return list[seed % list.length];
  };

  const normalizeVenueName = (name) => {
    const clean = (name || "").trim();
    return clean === "India (Global)" ? "India" : clean;
  };

  const venueSlug = (name) =>
    normalizeVenueName(name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

  const openVenueDetails = (venueName, updateHash = true) => {
    const key = normalizeVenueName(venueName);
    const info = venueInfo[key];
    if (!info || !DOM.venueModal) return;

    DOM.venueModalGroup.textContent = info.group;
    const subVenues = subVenueNames[key] || (info.forts || []).map((fort) => fort.name);
    DOM.venueModalTitle.textContent = `${key} sub-venues and forts`;
    DOM.venueModalHistory.textContent = `${info.history} Listed below are the actual in-game sub-venues configured for this kingdom.`;
    DOM.venueFortList.innerHTML = "";

    subVenues.forEach((subVenueName, index) => {
      const item = document.createElement("article");
      item.className = "venue-fort-item";
      const title = document.createElement("h3");
      title.textContent = `${String(index + 1).padStart(2, "0")}. ${subVenueName}`;
      const about = document.createElement("p");
      about.textContent = `In-game sub-venue under ${key}. ${subVenueAbout(key, subVenueName)}.`;
      item.append(title, about);
      DOM.venueFortList.appendChild(item);
    });

    toggleModal(DOM.venueModal, true);
    if (updateHash) {
      window.history.pushState(null, "", `#forts-${venueSlug(key)}`);
    }
  };

  const setupVenueCards = () => {
    document.querySelectorAll(".venue-card").forEach((card) => {
      const heading = card.querySelector("h4");
      const key = normalizeVenueName(heading?.textContent);
      const info = venueInfo[key];
      if (!info) return;

      card.tabIndex = 0;
      card.setAttribute("role", "link");
      card.setAttribute("aria-label", `Open sub-venues and forts for ${key}`);
      card.dataset.venue = key;
      card.dataset.href = `#forts-${venueSlug(key)}`;

      if (!card.querySelector(".venue-card-history")) {
        const overlay = document.createElement("div");
        overlay.className = "venue-card-history";
        const text = document.createElement("p");
        text.textContent = info.history;
        const cta = document.createElement("span");
        cta.className = "venue-card-cta";
        cta.textContent = "Open sub-venue list";
        overlay.append(text, cta);
        card.appendChild(overlay);
      }

      card.addEventListener("click", () => openVenueDetails(key));
      card.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          openVenueDetails(key);
        }
      });
    });
  };

  document.addEventListener("click", (event) => {
    const inPopup = [DOM.aboutPopup, DOM.supportPopup, DOM.featurePopup].some(p => p.contains(event.target));
    const inTrigger = event.target.closest(".feature") || ["aboutLink", "supportLink"].includes(event.target.id);
    if (!inPopup && !inTrigger) {
      [DOM.aboutPopup, DOM.supportPopup, DOM.featurePopup].forEach(p => toggleModal(p, false));
      document.querySelectorAll(".feature").forEach(f => f.classList.remove("is-flipped"));
    }
  });

  const venueTabs = document.querySelectorAll(".venue-tab");
  const venueGrids = document.querySelectorAll(".venue-grid");
  const setVenueGroup = (target) => {
    venueTabs.forEach(tab => {
      const isActive = tab.dataset.target === target;
      tab.classList.toggle("active", isActive);
      tab.setAttribute("aria-selected", isActive);
    });
    venueGrids.forEach(grid => {
      const isMatch = grid.dataset.group === target;
      grid.classList.toggle("active", isMatch);
    });
  };
  if (venueTabs.length) {
    venueTabs.forEach(tab => {
      tab.addEventListener("click", () => setVenueGroup(tab.dataset.target));
    });
    // ensure default
    setVenueGroup(document.querySelector(".venue-tab.active")?.dataset.target || "world");
  }
  setupVenueCards();

  const openVenueFromHash = () => {
    const match = window.location.hash.match(/^#forts-(.+)$/);
    if (!match) return;
    const entry = Object.keys(venueInfo).find((name) => venueSlug(name) === match[1]);
    if (entry) openVenueDetails(entry, false);
  };
  openVenueFromHash();
  window.addEventListener("hashchange", openVenueFromHash);

  // Demo banner overlay + launch
  const demoBanner = document.querySelector(".demo-banner");
  if (demoBanner && demoLoader) {
    demoBanner.addEventListener("click", (e) => {
      e.preventDefault();
      const targetUrl = demoBanner.getAttribute("href");
      demoLoader.classList.add("show");
      setTimeout(() => {
        window.open(targetUrl, "_blank", "noopener");
        setTimeout(() => demoLoader.classList.remove("show"), 1800);
      }, 30);
    });
  }

  if (DOM.viewIdCardBtn) {
    DOM.viewIdCardBtn.addEventListener("click", () => {
      const showing = DOM.idCardDisplay.style.display === "block";
      DOM.idCardDisplay.style.display = showing ? "none" : "block";
      DOM.editProfileForm.style.display = "none";
      DOM.editProfileBtn.innerText = "Edit Profile";

      if (!showing) {
        const kingdomName = document.getElementById("profileKingdom").innerText;
        document.getElementById("idCardUsername").innerText = document.getElementById("profileUsername").innerText;
        document.getElementById("idCardKingdom").innerText = kingdomName;
        document.getElementById("idCardAbout").innerText ||= "Ready to win!";
        document.getElementById("idCardKingdomFlag").src = kingdomFlagSrc(kingdomName);
      }
    });
  }

  DOM.editProfileBtn?.addEventListener("click", () => {
    const isVisible = DOM.editProfileForm.style.display === "block";
    DOM.idCardDisplay.style.display = "none";
    DOM.editProfileForm.style.display = isVisible ? "none" : "block";
    DOM.editProfileBtn.innerText = isVisible ? "Edit Profile" : "Cancel Edit";

    if (!isVisible) {
      ["Username", "Email", "Kingdom"].forEach(field => {
        document.getElementById(`edit${field}`).value = document.getElementById(`profile${field}`).innerText;
      });
      document.getElementById("editAbout").value = document.getElementById("idCardAbout").innerText;
    }
  });

  DOM.editProfileForm?.addEventListener("submit", async (e) => {
    e.preventDefault();

    if (!auth || !auth.currentUser) {
      alert("Please login first.");
      return;
    }

    const user = auth.currentUser;
    const updated = {
      username: document.getElementById("editUsername").value.trim(),
      email: document.getElementById("editEmail").value.trim(),
      kingdom: document.getElementById("editKingdom").value.trim(),
      about: document.getElementById("editAbout").value.trim()
    };

    try {
      if (
        updated.username &&
        updated.username !== (user.displayName || "")
      ) {
        await user.updateProfile({ displayName: updated.username });
      }

      if (
        updated.email &&
        user.email &&
        updated.email.toLowerCase() !== user.email.toLowerCase()
      ) {
        alert("Email change isn’t supported here yet.");
      }

      writeExtraProfile(user.uid, {
        kingdom: updated.kingdom,
        about: updated.about
      });

      loadProfile(user);
      DOM.editProfileForm.style.display = "none";
      DOM.editProfileBtn.innerText = "Edit Profile";
      alert("Profile updated.");
    } catch (e2) {
      alert(firebaseErrorMessage(e2));
    }
  });

  document.getElementById("registerForm").addEventListener("submit", async e => {
    e.preventDefault();
    try {
      if (!auth) {
        alert("Auth is not available yet. Please refresh and try again.");
        return;
      }

      const email = document.getElementById("registerEmail").value.trim();
      const password = document.getElementById("registerPassword").value;
      const confirm = document.getElementById("confirmPassword").value;
      const username = document.getElementById("registerUsername").value.trim();
      const kingdom = document.getElementById("registerKingdom").value.trim();
      const about = document.getElementById("aboutUser").value.trim();

      if (password !== confirm) {
        alert("Passwords do not match.");
        return;
      }

      const cred = await auth.createUserWithEmailAndPassword(email, password);
      const user = cred.user;
      if (user && username) {
        await user.updateProfile({ displayName: username });
      }
      if (user) {
        writeExtraProfile(user.uid, { kingdom, about });
      }

      alert("Registered successfully.");
      if (user) loadProfile(user);
      document.getElementById("closeModal").click();
    } catch (err) {
      alert(firebaseErrorMessage(err));
    }
  });

  document.getElementById("loginForm").addEventListener("submit", async e => {
    e.preventDefault();
    try {
      if (!auth) {
        alert("Auth is not available yet. Please refresh and try again.");
        return;
      }

      const email = document.getElementById("loginEmail").value.trim();
      const password = document.getElementById("loginPassword").value;
      const cred = await auth.signInWithEmailAndPassword(email, password);
      if (cred.user) loadProfile(cred.user);
      document.getElementById("closeModal").click();
    } catch (err) {
      alert(firebaseErrorMessage(err));
    }
  });

  document.getElementById("logoutBtn").addEventListener("click", () => {
    if (!auth) {
      loadProfile(null);
      toggleModal(DOM.profileModal, false);
      return;
    }
    auth.signOut().finally(() => {
      loadProfile(null);
      toggleModal(DOM.profileModal, false);
      alert("You have been logged out.");
    });
  });

  const forgotPasswordLink = document.getElementById("forgotPasswordLink");
  if (forgotPasswordLink) {
    forgotPasswordLink.addEventListener("click", async (e) => {
      e.preventDefault();
      const email = document.getElementById("loginEmail").value;
      if (!email) return alert("Please enter your email first.");
      try {
        if (!auth) {
          alert("Auth is not available yet. Please refresh and try again.");
          return;
        }
        await auth.sendPasswordResetEmail(email.trim());
        alert("Password reset email sent.");
      } catch (err) {
        alert(firebaseErrorMessage(err));
      }
    });
  }

  async function populateLeaderboard() {
    try {
      const res = await fetch(`${API_URL}/api/leaderboard`);
      const data = await res.json();
      const tbody = document.getElementById("leaderboardTableBody");
      tbody.innerHTML = "";
      data.forEach(user => {
        const row = document.createElement("tr");
        row.innerHTML = `
          <td><img src="${user.photo}" alt="${user.username}" class="leaderboard-img"></td>
          <td>${user.username}</td>
          <td>${user.kingdom}</td>
          <td>${user.winnings}</td>`;
        tbody.appendChild(row);
      });
    } catch (err) {
      alert("Failed to load leaderboard.");
    }
  }

  function loadProfile(user) {
    const isSignedIn = Boolean(user);
    const logoutBtn = document.getElementById("logoutBtn");
    if (logoutBtn) logoutBtn.style.display = isSignedIn ? "" : "none";
    if (DOM.editProfileBtn) DOM.editProfileBtn.style.display = isSignedIn ? "" : "none";
    if (DOM.viewIdCardBtn) DOM.viewIdCardBtn.style.display = isSignedIn ? "" : "none";

    if (!isSignedIn) {
      if (DOM.editProfileForm) DOM.editProfileForm.style.display = "none";
      if (DOM.idCardDisplay) DOM.idCardDisplay.style.display = "none";
    }

    if (user) {
      const extra = user.uid ? readExtraProfile(user.uid) : {};
      const username = user.displayName || extra.username || "Player";
      const email = user.email || "—";
      const kingdom = extra.kingdom || "Not Set";
      const about = extra.about || "Ready to win!";
      const avatarUrl = user.photoURL || "Renoir.png";

      document.getElementById("profileUsername").innerText = username;
      document.getElementById("profileEmail").innerText = email;
      document.getElementById("profileKingdom").innerText = kingdom;
      document.getElementById("profilePrizeMoney").innerText = "$0.00";
      document.getElementById("idCardAbout").innerText = about;

      const avatarEl = document.getElementById("profileAvatar");
      if (avatarEl) avatarEl.src = avatarUrl;
      const idPhotoEl = document.getElementById("idCardPhoto");
      if (idPhotoEl) idPhotoEl.src = avatarUrl;
    } else {
      document.getElementById("profileUsername").innerText = "Guest";
      document.getElementById("profileEmail").innerText = "guest@example.com";
      document.getElementById("profileKingdom").innerText = "Not Set";
      document.getElementById("profilePrizeMoney").innerText = "$0.00";
      document.getElementById("idCardAbout").innerText = "Ready to win!";

      const avatarEl = document.getElementById("profileAvatar");
      if (avatarEl) avatarEl.src = "Renoir.png";
      const idPhotoEl = document.getElementById("idCardPhoto");
      if (idPhotoEl) idPhotoEl.src = "Renoir.png";
    }
  }

  function bindAuthState() {
    if (!auth) {
      loadProfile(null);
      return;
    }
    auth.onAuthStateChanged((u) => loadProfile(u));
  }

  bindAuthState();
});
