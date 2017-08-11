import Cookies from 'js-cookie';
import bp from './breakpoints';

export const canShowActiveSubItems = (el) => {
  const isHiddenByMedia = bp.getBreakpointSize() === 'sm' || bp.getBreakpointSize() === 'md';

  if (el.classList.contains('active') && !isHiddenByMedia) {
    return Cookies.get('sidebar_collapsed') === 'true';
  }

  return true;
};
export const canShowSubItems = () => bp.getBreakpointSize() === 'sm' || bp.getBreakpointSize() === 'md' || bp.getBreakpointSize() === 'lg';

export const calculateTop = (boundingRect, outerHeight) => {
  const windowHeight = window.innerHeight;
  const bottomOverflow = windowHeight - (boundingRect.top + outerHeight);

  return bottomOverflow < 0 ? (boundingRect.top - outerHeight) + boundingRect.height :
    boundingRect.top;
};

export const showSubLevelItems = (el) => {
  const subItems = el.querySelector('.sidebar-sub-level-items');

  if (!subItems || !canShowSubItems() || !canShowActiveSubItems(el)) return;

  subItems.style.display = 'block';
  el.classList.add('is-showing-fly-out');
  el.classList.add('is-over');

  const boundingRect = el.getBoundingClientRect();
  const top = calculateTop(boundingRect, subItems.offsetHeight);
  const isAbove = top < boundingRect.top;

  subItems.classList.add('fly-out-list');
  subItems.style.transform = `translate3d(0, ${Math.floor(top)}px, 0)`;

  if (isAbove) {
    subItems.classList.add('is-above');
  }
};

export const hideSubLevelItems = (el) => {
  const subItems = el.querySelector('.sidebar-sub-level-items');

  if (!subItems || !canShowSubItems() || !canShowActiveSubItems(el)) return;

  el.classList.remove('is-showing-fly-out');
  el.classList.remove('is-over');
  subItems.style.display = '';
  subItems.style.transform = '';
  subItems.classList.remove('is-above');
};

export default () => {
  const items = [...document.querySelectorAll('.sidebar-top-level-items > li')]
    .filter(el => el.querySelector('.sidebar-sub-level-items'));

  items.forEach((el) => {
    el.addEventListener('mouseenter', e => showSubLevelItems(e.currentTarget));
    el.addEventListener('mouseleave', e => hideSubLevelItems(e.currentTarget));
  });
};
