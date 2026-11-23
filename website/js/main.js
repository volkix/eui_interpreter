/* Euphorix Website Interactivity */
document.addEventListener('DOMContentLoaded', function() {
  // 1. Mobile Menu Toggle
  var toggle = document.querySelector('.mobile-toggle');
  var links = document.querySelector('.nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', function() {
      links.classList.toggle('show');
    });
    // Close menu when clicking link
    links.querySelectorAll('a').forEach(function(a) {
      a.addEventListener('click', function() {
        links.classList.remove('show');
      });
    });
  }

  // 2. Terminal Code Tabs
  var tabs = document.querySelectorAll('.terminal-tab');
  tabs.forEach(function(tab) {
    tab.addEventListener('click', function() {
      var targetId = this.getAttribute('data-target');
      tabs.forEach(function(t) { t.classList.remove('active'); });
      document.querySelectorAll('.code-tab-content').forEach(function(c) {
        c.classList.remove('active');
      });
      this.classList.add('active');
      var target = document.getElementById(targetId);
      if (target) target.classList.add('active');
    });
  });

  // 3. Tutorial Live Search & Category Filter
  var searchInput = document.getElementById('tutorial-search');
  var clearBtn = document.getElementById('clear-search');
  var filterPills = document.querySelectorAll('.filter-pill');
  var chapterSections = document.querySelectorAll('.tutorial-chapter-section');
  var sidebarGroups = document.querySelectorAll('.sidebar-chap-group');

  function applyTutorialFilter() {
    var query = searchInput ? searchInput.value.toLowerCase().trim() : '';
    var activePill = document.querySelector('.filter-pill.active');
    var activeCat = activePill ? activePill.getAttribute('data-filter') : 'all';

    if (clearBtn) clearBtn.style.display = query.length > 0 ? 'inline-block' : 'none';

    chapterSections.forEach(function(sec) {
      var secCat = sec.getAttribute('data-cat');
      var catMatches = (activeCat === 'all' || activeCat === secCat);
      var visibleCardsCount = 0;

      var secCards = sec.querySelectorAll('.tutorial-card');
      secCards.forEach(function(card) {
        var cardText = card.textContent.toLowerCase();
        var cardKeywords = (card.getAttribute('data-keywords') || '').toLowerCase();
        var searchMatches = (query === '' || cardText.indexOf(query) !== -1 || cardKeywords.indexOf(query) !== -1);

        if (catMatches && searchMatches) {
          card.style.display = 'block';
          visibleCardsCount++;
        } else {
          card.style.display = 'none';
        }
      });

      if (visibleCardsCount > 0) {
        sec.style.display = 'block';
      } else {
        sec.style.display = 'none';
      }
    });

    sidebarGroups.forEach(function(grp) {
      var grpCat = grp.getAttribute('data-cat');
      if (activeCat === 'all' || activeCat === grpCat) {
        grp.style.display = 'block';
      } else {
        grp.style.display = 'none';
      }
    });
  }

  if (searchInput) {
    searchInput.addEventListener('input', applyTutorialFilter);
  }
  if (clearBtn) {
    clearBtn.addEventListener('click', function() {
      searchInput.value = '';
      applyTutorialFilter();
      searchInput.focus();
    });
  }

  filterPills.forEach(function(pill) {
    pill.addEventListener('click', function() {
      filterPills.forEach(function(p) { p.classList.remove('active'); });
      this.classList.add('active');
      applyTutorialFilter();
    });
  });
});

// Copy snippet to clipboard
function copyCommand(text, btnElement) {
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(function() {
      var oldText = btnElement.textContent;
      btnElement.textContent = "Kopiert!";
      setTimeout(function() { btnElement.textContent = oldText; }, 2000);
    });
  }
}

function copySnippet(btn) {
  var card = btn.closest('.tutorial-card');
  if (card) {
    var codeEl = card.querySelector('code');
    if (codeEl) {
      copyCommand(codeEl.textContent, btn);
    }
  }
}
