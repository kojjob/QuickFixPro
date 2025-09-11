# QuickFixPro Style Guide

## Design Philosophy
QuickFixPro follows a modern, professional design system inspired by enterprise admin dashboards. The design emphasizes clarity, functionality, and a clean aesthetic that promotes productivity and ease of use.

## Color Palette

### Primary Colors
- **Primary Blue**: `#556ee6` (rgb(85, 110, 230))
  - Used for: Primary buttons, active states, links
  - Tailwind: `blue-600`
  
- **Primary Indigo**: `#564ab1` (rgb(86, 74, 177))
  - Used for: Gradient accents, secondary highlights
  - Tailwind: `indigo-600`

### Gradient Schemes
- **Primary Gradient**: `from-blue-500 to-indigo-600`
  - Used for: Welcome banners, user avatars, feature highlights
  
- **Secondary Gradient**: `from-indigo-500 to-purple-600`
  - Used for: Profile avatars, accent elements

### Status Colors
- **Success Green**: `#34c38f` (rgb(52, 195, 143))
  - Tailwind: `green-500/600`
  - Used for: Success messages, active status, positive metrics
  
- **Warning Yellow**: `#f1b44c` (rgb(241, 180, 76))
  - Tailwind: `yellow-500/600`
  - Used for: Warnings, attention items, medium priority
  
- **Danger Red**: `#f46a6a` (rgb(244, 106, 106))
  - Tailwind: `red-500/600`
  - Used for: Errors, critical issues, negative trends

### Neutral Colors
- **Gray Scale**:
  - `gray-50`: Background for cards on gray backgrounds
  - `gray-100`: Subtle backgrounds, hover states
  - `gray-200`: Borders, dividers
  - `gray-300`: Disabled states, subtle borders
  - `gray-400`: Placeholder text
  - `gray-500`: Secondary text
  - `gray-600`: Body text
  - `gray-700`: Primary text (alternative)
  - `gray-800`: Headings
  - `gray-900`: Primary headings, strong emphasis

### Background Colors
- **Page Background**: `bg-gray-50` (#F9FAFB)
- **Card Background**: `bg-white` (#FFFFFF)
- **Header Background**: `bg-white` with `border-b border-gray-200`
- **Navigation Background**: `bg-gray-50` for secondary nav

## Typography

### Font Family
- **Primary Font**: System font stack
  ```css
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  ```

### Font Sizes
- **Page Title**: `text-2xl` (1.5rem / 24px) `font-semibold`
- **Section Heading**: `text-lg` (1.125rem / 18px) `font-semibold`
- **Card Title**: `text-lg` (1.125rem / 18px) `font-semibold`
- **Body Text**: `text-sm` (0.875rem / 14px)
- **Small Text**: `text-xs` (0.75rem / 12px)
- **Large Numbers**: `text-2xl` (1.5rem / 24px) `font-bold`

### Text Colors
- **Primary Text**: `text-gray-900`
- **Secondary Text**: `text-gray-600`
- **Muted Text**: `text-gray-500`
- **Link Text**: `text-blue-600 hover:text-blue-700`

## Layout Structure

### Page Layout
```
┌─────────────────────────────────────────┐
│         Fixed Header (h-16)             │
├─────────────────────────────────────────┤
│     Horizontal Navigation (h-12)        │
├─────────────────────────────────────────┤
│                                         │
│         Main Content Area               │
│         (max-w-7xl mx-auto)            │
│                                         │
└─────────────────────────────────────────┘
```

### Grid System
- **Container**: `max-w-7xl mx-auto px-4`
- **Grid Layouts**:
  - Dashboard: `grid grid-cols-1 lg:grid-cols-3 gap-6`
  - Cards Row: `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`
  - Two Column: `grid grid-cols-1 lg:grid-cols-2 gap-6`

### Spacing
- **Page Padding**: `p-4`
- **Card Padding**: `p-6`
- **Section Spacing**: `mb-6`
- **Element Spacing**: `space-y-4` or `space-x-4`

## Components

### Cards
```html
<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
  <!-- Card content -->
</div>
```

### Buttons

#### Primary Button
```html
<button class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
  Button Text
</button>
```

#### Secondary Button
```html
<button class="px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
  Button Text
</button>
```

#### Icon Button
```html
<button class="p-2 rounded-lg hover:bg-gray-100">
  <svg class="w-5 h-5 text-gray-600"><!-- Icon --></svg>
</button>
```

### Status Badges
```html
<!-- Success -->
<span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-800 rounded-full">Active</span>

<!-- Warning -->
<span class="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full">Pending</span>

<!-- Danger -->
<span class="px-2 py-1 text-xs font-medium bg-red-100 text-red-800 rounded-full">Critical</span>

<!-- Info -->
<span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded-full">Info</span>
```

### Form Elements

#### Input Field
```html
<input type="text" 
       class="mt-1 block w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
```

#### Select Dropdown
```html
<select class="mt-1 block w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
  <option>Option 1</option>
</select>
```

### Navigation

#### Horizontal Menu Item
```html
<a href="#" class="text-sm font-medium text-gray-700 hover:text-blue-600 transition-colors">
  Menu Item
</a>
```

#### Dropdown Menu
```html
<div class="relative group">
  <button class="text-sm font-medium text-gray-700 hover:text-blue-600 flex items-center">
    Menu Item
    <svg class="w-4 h-4 ml-1"><!-- Chevron down --></svg>
  </button>
  <div class="absolute top-full left-0 mt-2 w-48 bg-white rounded-lg shadow-lg border border-gray-200 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200">
    <!-- Dropdown items -->
  </div>
</div>
```

### Alerts & Notifications

#### Success Alert
```html
<div class="bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded-lg flex items-center">
  <svg class="w-5 h-5 mr-2 text-green-600"><!-- Check icon --></svg>
  Success message here
</div>
```

#### Error Alert
```html
<div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg flex items-center">
  <svg class="w-5 h-5 mr-2 text-red-600"><!-- X icon --></svg>
  Error message here
</div>
```

## Icons

### Icon Sizes
- **Large**: `w-6 h-6` (24px)
- **Medium**: `w-5 h-5` (20px)
- **Small**: `w-4 h-4` (16px)

### Icon Colors
- **Default**: `text-gray-600`
- **Active/Primary**: `text-blue-600`
- **Success**: `text-green-600`
- **Warning**: `text-yellow-600`
- **Danger**: `text-red-600`

### Common Icons (Heroicons)
- **Dashboard**: Grid icon
- **Websites**: Globe icon
- **Settings**: Cog icon
- **User**: User icon
- **Notifications**: Bell icon
- **Search**: Magnifying glass icon
- **Menu**: Bars icon
- **Close**: X icon
- **Check**: Check icon
- **Alert**: Exclamation icon

## Data Visualization

### Charts
- **Bar Charts**: Use blue-500 as primary color
- **Line Charts**: Use gradient from blue-400 to blue-600
- **Tooltips**: Dark gray background with white text

### Progress Bars
```html
<div class="w-full bg-gray-200 rounded-full h-2">
  <div class="bg-blue-600 h-2 rounded-full" style="width: 75%"></div>
</div>
```

### Stat Cards
```html
<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
  <div class="flex items-center justify-between mb-4">
    <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
      <svg class="w-6 h-6 text-blue-600"><!-- Icon --></svg>
    </div>
    <span class="px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
      +12%
    </span>
  </div>
  <h3 class="text-2xl font-bold text-gray-900">1,234</h3>
  <p class="text-sm text-gray-500 mt-1">Metric Label</p>
</div>
```

## Responsive Design

### Breakpoints
- **Mobile**: Default (< 640px)
- **Tablet**: `sm:` (≥ 640px)
- **Desktop**: `lg:` (≥ 1024px)
- **Wide**: `xl:` (≥ 1280px)

### Mobile Considerations
- Stack columns on mobile: `grid-cols-1 lg:grid-cols-3`
- Hide on mobile: `hidden lg:block`
- Show on mobile only: `lg:hidden`
- Adjust padding: `p-4 lg:p-6`

## Animation & Transitions

### Hover Effects
- **Buttons**: `hover:bg-{color}-700 transition-colors`
- **Links**: `hover:text-{color}-700 transition-colors`
- **Cards**: `hover:shadow-md transition-shadow`

### Dropdown Animation
```css
@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.dropdown-enter {
  animation: slideDown 0.2s ease-out;
}
```

### Transition Classes
- **Fast**: `transition-all duration-200`
- **Normal**: `transition-all duration-300`
- **Slow**: `transition-all duration-500`

## Accessibility

### Focus States
- **Buttons**: `focus:ring-2 focus:ring-blue-500 focus:ring-offset-2`
- **Inputs**: `focus:ring-2 focus:ring-blue-500 focus:border-blue-500`
- **Links**: `focus:outline-none focus:ring-2 focus:ring-blue-500`

### ARIA Labels
- Always include `aria-label` for icon-only buttons
- Use `role` attributes appropriately
- Include `alt` text for images
- Ensure proper heading hierarchy

### Keyboard Navigation
- All interactive elements must be keyboard accessible
- Use proper tab order
- Include skip links for main content
- Escape key closes modals/dropdowns

## Best Practices

### Performance
1. Use Tailwind's purge feature in production
2. Lazy load images below the fold
3. Minimize custom CSS
4. Use SVG icons instead of icon fonts

### Consistency
1. Use the defined color palette consistently
2. Maintain spacing patterns throughout
3. Keep button styles uniform
4. Use consistent border radius (rounded-lg)

### User Experience
1. Provide clear hover states
2. Show loading states for async operations
3. Include proper error handling
4. Maintain visual hierarchy
5. Use clear, actionable button text

### Code Organization
1. Extract repeated patterns into components
2. Use Tailwind's @apply for complex repeated styles
3. Keep utility classes ordered (position, display, spacing, colors)
4. Comment complex styling decisions

## Component Examples

### Dashboard Welcome Banner
```html
<div class="bg-gradient-to-r from-blue-500 to-indigo-600 rounded-lg p-6 text-white">
  <h2 class="text-2xl font-semibold mb-2">Welcome back!</h2>
  <p class="text-blue-100">Here's what's happening today.</p>
</div>
```

### Data Table Row
```html
<tr class="hover:bg-gray-50">
  <td class="px-4 py-3 text-sm text-gray-900">Data</td>
  <td class="px-4 py-3 text-sm text-gray-600">Secondary</td>
  <td class="px-4 py-3 text-sm text-right">
    <span class="text-green-600 font-medium">95%</span>
  </td>
</tr>
```

### Empty State
```html
<div class="text-center py-8">
  <svg class="w-12 h-12 text-gray-400 mx-auto mb-3"><!-- Icon --></svg>
  <p class="text-gray-600">No data available</p>
  <p class="text-xs text-gray-500 mt-1">Get started by adding your first item</p>
  <button class="mt-3 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
    Add Item
  </button>
</div>
```

---

This style guide should be treated as a living document and updated as the design system evolves. All new components and pages should follow these guidelines to maintain consistency across the application.