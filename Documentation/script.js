const navLinks = document.querySelectorAll('.nav-links a');

navLinks.forEach(link => {
    link.addEventListener('click', function(e) {
        e.preventDefault();
        
        navLinks.forEach(l => l.classList.remove('active'));
        
        this.classList.add('active');
    
        let parent = this.closest('ul.sub-links');
        if (parent) {
            const parentLink = parent.previousElementSibling;
            if (parentLink && parentLink.tagName === 'A') {
                parentLink.classList.add('active');
            }
        }
    
        let grandparent = this.closest('ul.sub-sub-links');
        if (grandparent) {
            const subParent = grandparent.previousElementSibling;
            if (subParent && subParent.tagName === 'A') {
                subParent.classList.add('active');
            }
            const mainParent = grandparent.closest('ul.sub-links');
            if (mainParent) {
                const topParent = mainParent.previousElementSibling;
                if (topParent && topParent.tagName === 'A') {
                    topParent.classList.add('active');
                }
            }
        }
        
        const href = this.getAttribute('href');
        const target = document.querySelector(href);
        if (target) {
            const offsetTop = target.offsetTop - 50;
            window.scrollTo({
                top: offsetTop,
                behavior: 'smooth'
            });
        }
    });
});

window.addEventListener('scroll', () => {
    let current = '';
    const sections = document.querySelectorAll('section');
    const scrollPos = window.pageYOffset + 50;
    
    let closestSection = null;
    let closestDistance = Infinity;
    
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        const sectionBottom = sectionTop + section.offsetHeight;
    
        if (scrollPos >= sectionTop && scrollPos < sectionBottom) {
            closestSection = section;
            closestDistance = 0;
        } 
        
        else if (scrollPos < sectionTop && sectionTop - scrollPos < closestDistance) {
            closestSection = section;
            closestDistance = sectionTop - scrollPos;
        }
    });
    
    if (closestSection) {
        current = closestSection.getAttribute('id');
    }
    
    if (current) {
        navLinks.forEach(link => link.classList.remove('active'));
        
        const currentLink = document.querySelector(`.nav-links a[href="#${current}"]`);
        if (currentLink) {
            currentLink.classList.add('active');
            
            let parent = currentLink.closest('ul.sub-links');
            if (parent) {
                const parentLink = parent.previousElementSibling;
                if (parentLink && parentLink.tagName === 'A') {
                    parentLink.classList.add('active');
                }
            }
            
            let grandparent = currentLink.closest('ul.sub-sub-links');
            if (grandparent) {
                const subParent = grandparent.previousElementSibling;
                if (subParent && subParent.tagName === 'A') {
                    subParent.classList.add('active');
                }
                const mainParent = grandparent.closest('ul.sub-links');
                if (mainParent) {
                    const topParent = mainParent.previousElementSibling;
                    if (topParent && topParent.tagName === 'A') {
                        topParent.classList.add('active');
                    }
                }
            }
        }
    }
});
